
using FreelancePlatform.Repositories;

namespace FreelancePlatform.UnitOfWork;

public interface IUnitOfWork : IAsyncDisposable
{
    IJobRepository Jobs { get; }
    IProposalRepository Proposals { get; }
    IContractRepository Contracts { get; }

    Task BeginAsync();
    Task CommitAsync();
    Task RollbackAsync();
}
