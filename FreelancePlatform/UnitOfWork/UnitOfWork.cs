
using FreelancePlatform.Repositories;
using Npgsql;

namespace FreelancePlatform.UnitOfWork;

public class UnitOfWork : IUnitOfWork
{
    private readonly NpgsqlConnection _connection;
    private NpgsqlTransaction? _transaction;

    public IJobRepository Jobs { get; private set; }
        = null!;

    public IProposalRepository Proposals { get; private set; }
        = null!;

    public IContractRepository Contracts { get; private set; }
        = null!;

    public UnitOfWork(NpgsqlDataSource dataSource)
    {
        _connection = dataSource.CreateConnection();
    }

    public async Task BeginAsync()
    {
        if (_transaction != null)
            throw new InvalidOperationException(
                "A transaction is already active.");

        await _connection.OpenAsync();

        try
        {
            _transaction =
                await _connection.BeginTransactionAsync();

            Jobs = new JobRepository(
                _connection, _transaction);

            Proposals = new ProposalRepository(
                _connection, _transaction);

            Contracts = new ContractRepository(
                _connection, _transaction);
        }
        catch
        {
            await _connection.DisposeAsync();
            throw;
        }
    }

    public async Task CommitAsync()
    {
        if (_transaction == null)
            throw new InvalidOperationException(
                "No active transaction.");

        await _transaction.CommitAsync();
        await _transaction.DisposeAsync();
        _transaction = null;

        await _connection.CloseAsync();
    }

    public async Task RollbackAsync()
    {
        if (_transaction == null)
            return;

        try
        {
            await _transaction.RollbackAsync();
        }
        finally
        {
            await _transaction.DisposeAsync();
            _transaction = null;
            await _connection.CloseAsync();
        }
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            if (_transaction != null)
                await RollbackAsync();
        }
        finally
        {
            await _connection.DisposeAsync();
        }
    }
}
