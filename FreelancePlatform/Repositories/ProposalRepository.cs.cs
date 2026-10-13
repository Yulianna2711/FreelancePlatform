
using FreelancePlatform.Models;
using Npgsql;
using NpgsqlTypes;

namespace FreelancePlatform.Repositories;

public class ProposalRepository : IProposalRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly NpgsqlTransaction _transaction;

    public ProposalRepository(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction)
    {
        _connection = connection;
        _transaction = transaction;
    }

    public async Task<IReadOnlyList<Proposal>>
        GetActiveProposalsAsync()
    {
        var proposals = new List<Proposal>();

        const string sql = """
            SELECT
            proposal_id,  
            job_id,
            freelancer_id,
            proposed_price, 
            cover_letter,
            submitted_at
            FROM active_proposals_view
            ORDER BY submitted_at DESC;
            """;

        await using var command =
            new NpgsqlCommand(sql, _connection, _transaction);

        await using var reader =
            await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            proposals.Add(new Proposal
            {
                Id = reader.GetInt32(reader.GetOrdinal("proposal_id")), 
                JobId = reader.GetInt32(reader.GetOrdinal("job_id")),
                FreelancerId = reader.GetInt32(reader.GetOrdinal("freelancer_id")),
                Price = reader.GetDecimal(reader.GetOrdinal("proposed_price")), 
                CoverLetter = reader.IsDBNull(reader.GetOrdinal("cover_letter"))
         ? null
         : reader.GetString(reader.GetOrdinal("cover_letter")),
                SubmittedAt = reader.GetDateTime(reader.GetOrdinal("submitted_at"))
            });
        }

        return proposals;
    }

    public async Task<int> SubmitProposalAsync(
     int jobId,
     int freelancerId,
     decimal price,
     string? coverLetter)
    {
        await using var command = new NpgsqlCommand(
            """
        CALL submit_proposal(
            @job_id,
            @freelancer_id,
            @price,
            @cover_letter,
            NULL
        )
        """,
            _connection,
            _transaction
        );

        command.Parameters.AddWithValue("job_id", jobId);
        command.Parameters.AddWithValue("freelancer_id", freelancerId);
        command.Parameters.AddWithValue("price", price);
        command.Parameters.AddWithValue(
            "cover_letter",
            (object?)coverLetter ?? DBNull.Value
        );

        await using var reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException(
                "Не вдалося отримати ID створеної пропозиції."
            );
        }

        return reader.GetInt32(0);
    }
}
