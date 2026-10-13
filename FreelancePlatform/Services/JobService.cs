
using FreelancePlatform.Models;
using FreelancePlatform.UnitOfWork;

namespace FreelancePlatform.Services;

public class JobService
{
    private readonly Func<IUnitOfWork> _unitOfWorkFactory;

    public JobService(Func<IUnitOfWork> unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    public async Task<IReadOnlyList<Job>> GetActiveJobsAsync()
    {
        await using var unitOfWork = _unitOfWorkFactory();

        await unitOfWork.BeginAsync();

        try
        {
            var jobs = await unitOfWork.Jobs.GetActiveJobsAsync();

            await unitOfWork.CommitAsync();

            return jobs;
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
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
        if (price <= 0)
        {
            throw new ArgumentException(
                "Job price must be greater than zero.",
                nameof(price));
        }

        await using var unitOfWork = _unitOfWorkFactory();

        await unitOfWork.BeginAsync();

        try
        {
            int jobId = await unitOfWork.Jobs.CreateJobAsync(
                clientId,
                categoryId,
                title,
                price,
                employmentType,
                freelancersCount,
                description);

            await unitOfWork.CommitAsync();

            return jobId;
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
    }
}
