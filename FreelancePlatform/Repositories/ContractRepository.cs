
using Npgsql;

namespace FreelancePlatform.Repositories;

public class ContractRepository : IContractRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly NpgsqlTransaction _transaction;

    public ContractRepository(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction)
    {
        _connection = connection;
        _transaction = transaction;
    }

    public async Task CreateContractAsync(
        int proposalId,
        DateTime startDate,
        decimal price)
    {
        const string sql = """
            CALL create_contract(
                @p_proposal_id,
                @p_start_date,
                @p_price
            );
            """;

        await using var command =
            new NpgsqlCommand(sql, _connection, _transaction);

        command.Parameters.AddWithValue(
            "p_proposal_id", proposalId);

        command.Parameters.AddWithValue(
            "p_start_date", startDate);

        command.Parameters.AddWithValue(
            "p_price", price);

        await command.ExecuteNonQueryAsync();
    }
}
