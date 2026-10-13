using FreelancePlatform;
using FreelancePlatform.Services;
using FreelancePlatform.UnitOfWork;

class Program
{
    static async Task Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        await using var dataSource = DatabaseConnection.CreateDataSource();

        Func<IUnitOfWork> unitOfWorkFactory =
            () => new UnitOfWork(dataSource);

        var jobService = new JobService(unitOfWorkFactory);
        var proposalService = new ProposalService(unitOfWorkFactory);
        var contractService = new ContractService(unitOfWorkFactory);

        try
        {
            Console.WriteLine("Active jobs:");

            var activeJobs = await jobService.GetActiveJobsAsync();

            if (activeJobs.Count == 0)
            {
                Console.WriteLine("No active jobs found at the moment.");
            }
            else
            {
                foreach (var job in activeJobs)
                {
                    Console.WriteLine(
                        $"Job #{job.Id}: \"{job.Title}\" | Budget: ${job.Price}");
                }
            }


            int jobId = await jobService.CreateJobAsync(
                clientId: 2,
                categoryId: 1,
                title: "Fullstack .NET & PostgreSQL Developer",
                price: 3000.00m,
                employmentType: "Remote",
                freelancersCount: 1,
                description:
                    "Backend development utilizing ADO.NET and complex database constraints."
            );

            Console.WriteLine(
                $"The new job #{jobId} is successfully created.");


            int proposalId = await proposalService.SubmitProposalAsync(
                jobId: jobId,
                freelancerId: 4,
                price: 2900.00m,
                coverLetter:
                    "I have extensive experience in relational database design and C#."
            );

            Console.WriteLine(
                $"The proposal #{proposalId} is successfully submitted.");

 
            await contractService.HireFreelancerAndCreateContractAsync(
                proposalId: proposalId,
                startDate: DateTime.UtcNow,
                price: 2900.00m
            );

            Console.WriteLine("The contract has been concluded.");
        }
        catch (Exception ex)
        {
            Console.WriteLine(
                $"\n[ERROR] Operation failed. Reason: {ex.Message}");
        }
    }
}
