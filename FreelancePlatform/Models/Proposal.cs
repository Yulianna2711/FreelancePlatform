
namespace FreelancePlatform.Models;

public class Proposal
{
    public int Id { get; set; }
    public int JobId { get; set; }
    public int FreelancerId { get; set; }

    public decimal Price { get; set; }
    public string? CoverLetter { get; set; }

    public DateTime SubmittedAt { get; set; }
}
