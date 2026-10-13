
namespace FreelancePlatform.Repositories;

public interface IContractRepository
{
    Task CreateContractAsync(
        int proposalId,
        DateTime startDate,
        decimal price);
}
