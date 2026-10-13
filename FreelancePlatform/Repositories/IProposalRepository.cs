
using FreelancePlatform.Models;

namespace FreelancePlatform.Repositories;

public interface IProposalRepository
{
    Task<IReadOnlyList<Proposal>> GetActiveProposalsAsync();

    Task<int> SubmitProposalAsync(
        int jobId,
        int freelancerId,
        decimal price,
        string? coverLetter);
}
