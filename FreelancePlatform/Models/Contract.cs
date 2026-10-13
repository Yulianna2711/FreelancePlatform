
namespace FreelancePlatform.Models;

public class Contract
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public int ProposalId { get; set; }
    public int ClientId { get; set; }
    public int FreelancerId { get; set; }

    public DateTime StartDate { get; set; }
    public decimal Price { get; set; }
}
