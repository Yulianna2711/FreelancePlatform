
using FreelancePlatform.Models;
using Npgsql;
using NpgsqlTypes;

namespace FreelancePlatform.Repositories;

public class JobRepository : IJobRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly NpgsqlTransaction _transaction;

    public JobRepository(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction)
    {
        _connection = connection;
        _transaction = transaction;
    }

    public async Task<IReadOnlyList<Job>> GetActiveJobsAsync()
    {
        var jobs = new List<Job>();

        const string sql = """
            SELECT
                job_id AS id,
                client_id,
                category_id,
                title,
                price,
                employment_type,
                freelancers_count,
                description,
                created_at
            FROM active_jobs_view
            ORDER BY created_at DESC;
            """;

        await using var command =
            new NpgsqlCommand(sql, _connection, _transaction);

        await using var reader =
            await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            jobs.Add(new Job
            {
                Id = reader.GetInt32(reader.GetOrdinal("id")),
                ClientId = reader.GetInt32(
                    reader.GetOrdinal("client_id")),
                CategoryId = reader.GetInt32(
                    reader.GetOrdinal("category_id")),
                Title = reader.GetString(
                    reader.GetOrdinal("title")),
                Price = reader.GetDecimal(
                    reader.GetOrdinal("price")),
                EmploymentType = reader.GetString(
                    reader.GetOrdinal("employment_type")),
                FreelancersCount = reader.GetInt32(
                    reader.GetOrdinal("freelancers_count")),
                Description = reader.IsDBNull(
                    reader.GetOrdinal("description"))
                    ? null
                    : reader.GetString(
                        reader.GetOrdinal("description")),
                CreatedAt = reader.GetDateTime(
                    reader.GetOrdinal("created_at"))
            });
        }

        return jobs;
    }

    public async Task<int> CreateJobAsync(
        int clientId,
        int categoryId,
        string title,
        decimal price,
        string employmentType,
        int freelancersCount,
        string? description)
    {
        await using var command = new NpgsqlCommand(
            """
        CALL create_job(
            @client_id,
            @category_id,
            @title,
            @price,
            @employment_type,
            @freelancers_count,
            @description,
            NULL
        )
        """,
            _connection,
            _transaction
        );

        command.Parameters.AddWithValue("client_id", clientId);
        command.Parameters.AddWithValue("category_id", categoryId);
        command.Parameters.AddWithValue("title", title);
        command.Parameters.AddWithValue("price", price);
        command.Parameters.AddWithValue(
            "employment_type", employmentType);
        command.Parameters.AddWithValue(
            "freelancers_count", freelancersCount);
        command.Parameters.AddWithValue(
            "description",
            (object?)description ?? DBNull.Value);

        await using var reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException(
                "The ID of the created vacancy can not be retrieved.");
        }

        return reader.GetInt32(0);
    }
    }
