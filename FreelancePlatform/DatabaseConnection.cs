
using Npgsql;

namespace FreelancePlatform;

public static class DatabaseConnection
{
    private const string ConnectionString =
        "Host=localhost;Port=5432;Database=freelance_platform;Username=postgres;Password=postgres";

    public static NpgsqlDataSource CreateDataSource()
    {
        return NpgsqlDataSource.Create(ConnectionString);
    }
}
