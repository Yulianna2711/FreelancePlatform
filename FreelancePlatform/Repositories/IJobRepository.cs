
using FreelancePlatform.Models;

namespace FreelancePlatform.Repositories;

public interface IJobRepository
{
    Task<IReadOnlyList<Job>> GetActiveJobsAsync();

    Task<int> CreateJobAsync(
        int clientId,
        int categoryId,
        string title,
        decimal price,
        string employmentType,
        int freelancersCount,
        string? description);
}
