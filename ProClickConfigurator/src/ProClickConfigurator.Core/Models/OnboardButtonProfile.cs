namespace ProClickConfigurator.Core.Models;

public sealed record OnboardButtonProfile(
    IReadOnlyDictionary<MouseButtonId, string> PrimaryAssignments,
    IReadOnlyDictionary<MouseButtonId, string> HyperShiftAssignments);
