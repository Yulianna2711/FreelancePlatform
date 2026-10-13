
namespace FreelancePlatform.Models;

public class Job
{
    public int Id { get; set; }
    public int ClientId { get; set; }
    public int CategoryId { get; set; }

    public string Title { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string EmploymentType { get; set; } = string.Empty;
    public int FreelancersCount { get; set; }
    public string? Description { get; set; }

    public DateTime CreatedAt { get; set; }
}
