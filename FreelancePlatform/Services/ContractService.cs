using FreelancePlatform.Models;
using FreelancePlatform.UnitOfWork;

namespace FreelancePlatform.Services;

public class ContractService
{
    private readonly Func<IUnitOfWork> _unitOfWorkFactory;

    public ContractService(Func<IUnitOfWork> unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }
    public async Task HireFreelancerAndCreateContractAsync(
        int proposalId,
        DateTime startDate,
        decimal price)
    {
        await using var unitOfWork = _unitOfWorkFactory();
        await unitOfWork.BeginAsync();

        try
        {
            var activeProposals = await unitOfWork.Proposals.GetActiveProposalsAsync();

            var proposal = activeProposals.FirstOrDefault(p => p.Id == proposalId);

            if (proposal == null)
            {
                throw new InvalidOperationException($"Active proposal with ID {proposalId} was not found.");
            }

            if (price < 0)
            {
                throw new ArgumentException("Contract price must be greater than or equal zero.");
            }

            await unitOfWork.Contracts.CreateContractAsync(
                proposalId: proposal.Id,
                startDate: startDate,
                price: price
            );

            await unitOfWork.CommitAsync();
        }
        catch
        {
            await unitOfWork.RollbackAsync();
            throw;
        }
    }
}