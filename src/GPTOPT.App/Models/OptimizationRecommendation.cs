namespace GPTOPT.App.Models;

public sealed class OptimizationRecommendation
{
    public bool IsSelected { get; set; }
    public string Id { get; init; } = string.Empty;
    public string Category { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string CurrentState { get; init; } = string.Empty;
    public string TargetState { get; init; } = string.Empty;
    public string Why { get; init; } = string.Empty;
    public string How { get; init; } = string.Empty;
    public string ExpectedImpact { get; init; } = string.Empty;
    public string Risk { get; init; } = "Low";
    public bool RequiresAdmin { get; init; }
    public bool RequiresReboot { get; init; }
    public bool CanApply { get; init; }

    public string Summary => $"{Title}  |  Impact: {ExpectedImpact}  |  Risk: {Risk}";
}
