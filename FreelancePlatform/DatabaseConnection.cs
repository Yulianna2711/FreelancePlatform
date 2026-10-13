using Microsoft.Extensions.Configuration;
using Npgsql;

namespace FreelancePlatform;

public static class DatabaseConnection
{
    public static NpgsqlDataSource CreateDataSource()
    {
        var configuration = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
            .Build();

        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");

        return NpgsqlDataSource.Create(connectionString);
    }
}