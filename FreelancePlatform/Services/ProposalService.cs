
using FreelancePlatform.Models;
using FreelancePlatform.UnitOfWork;

namespace FreelancePlatform.Services;

public class ProposalService
{
    private readonly Func<IUnitOfWork> _unitOfWorkFactory;

    public ProposalService(Func<IUnitOfWork> unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    public async Task<IReadOnlyList<Proposal>> GetActiveProposalsAsync()
    {
        await using var unitOfWork = _unitOfWorkFactory();

        await unitOfWork.BeginAsync();

        try
        {
            var proposals =
                await unitOfWork.Proposals.GetActiveProposalsAsync();

            await unitOfWork.CommitAsync();

            return proposals;
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
    }

    public async Task<int> SubmitProposalAsync(
        int jobId,
        int freelancerId,
        decimal price,
        string? coverLetter)
    {
        if (price <= 0)
        {
            throw new ArgumentException(
                "Proposal price must be greater than zero.",
                nameof(price));
        }

        await using var unitOfWork = _unitOfWorkFactory();

        await unitOfWork.BeginAsync();

        try
        {
            int proposalId =
                await unitOfWork.Proposals.SubmitProposalAsync(
                    jobId,
                    freelancerId,
                    price,
                    coverLetter);

            await unitOfWork.CommitAsync();

            return proposalId;
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
    }
}
