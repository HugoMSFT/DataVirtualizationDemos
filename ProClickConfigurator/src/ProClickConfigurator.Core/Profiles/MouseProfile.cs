using ProClickConfigurator.Core.Models;

namespace ProClickConfigurator.Core.Profiles;

public sealed class MouseProfile
{
    public const int CurrentSchemaVersion = 1;

    public int SchemaVersion { get; set; } = CurrentSchemaVersion;

    public string Name { get; set; } = "Default";

    public int CurrentDpi { get; set; } = 800;

    public List<int> DpiStages { get; set; } = [800];

    public int ActiveDpiStage { get; set; } = 1;

    public int PollingRateHz { get; set; } = 1000;

    public int IdleTimeSeconds { get; set; } = 300;

    public int LowBatteryThresholdPercent { get; set; } = 5;

    public Dictionary<MouseButtonId, string> PrimaryAssignments { get; set; } = [];

    public Dictionary<MouseButtonId, string> HyperShiftAssignments { get; set; } = [];

    public static MouseProfile CreateDefault()
    {
        var profile = new MouseProfile();
        foreach (var button in Enum.GetValues<MouseButtonId>())
        {
            profile.PrimaryAssignments[button] = WindowsActionCatalog.PassthroughId;
            profile.HyperShiftAssignments[button] = WindowsActionCatalog.PassthroughId;
        }

        return profile;
    }

    public MouseProfile Clone()
    {
        return new MouseProfile
        {
            SchemaVersion = SchemaVersion,
            Name = Name,
            CurrentDpi = CurrentDpi,
            DpiStages = [.. DpiStages],
            ActiveDpiStage = ActiveDpiStage,
            PollingRateHz = PollingRateHz,
            IdleTimeSeconds = IdleTimeSeconds,
            LowBatteryThresholdPercent = LowBatteryThresholdPercent,
            PrimaryAssignments = new Dictionary<MouseButtonId, string>(PrimaryAssignments),
            HyperShiftAssignments = new Dictionary<MouseButtonId, string>(HyperShiftAssignments),
        };
    }

    public void Normalize()
    {
        if (SchemaVersion > CurrentSchemaVersion)
        {
            throw new InvalidDataException(
                $"Profile schema {SchemaVersion} is newer than supported schema {CurrentSchemaVersion}.");
        }

        if (DpiStages is null
            || PrimaryAssignments is null
            || HyperShiftAssignments is null)
        {
            throw new InvalidDataException("Profile collections cannot be null.");
        }

        SchemaVersion = CurrentSchemaVersion;
        Name = string.IsNullOrWhiteSpace(Name) ? "Default" : Name.Trim();
        CurrentDpi = Math.Clamp(RoundDpi(CurrentDpi), 100, 12000);
        DpiStages = DpiStages
            .Select(RoundDpi)
            .Select(value => Math.Clamp(value, 100, 12000))
            .Take(5)
            .ToList();

        if (DpiStages.Count == 0)
        {
            DpiStages.Add(CurrentDpi);
        }

        ActiveDpiStage = Math.Clamp(ActiveDpiStage, 1, DpiStages.Count);
        PollingRateHz = PollingRateHz is 125 or 500 or 1000 ? PollingRateHz : 1000;
        IdleTimeSeconds = Math.Clamp(IdleTimeSeconds, 60, 900);
        LowBatteryThresholdPercent = Math.Clamp(LowBatteryThresholdPercent, 5, 25);

        foreach (var button in Enum.GetValues<MouseButtonId>())
        {
            PrimaryAssignments[button] = NormalizeAction(PrimaryAssignments, button);
            HyperShiftAssignments[button] = NormalizeAction(HyperShiftAssignments, button);

            if (WindowsActionCatalog.Get(PrimaryAssignments[button]).MouseButton == button)
            {
                PrimaryAssignments[button] = WindowsActionCatalog.PassthroughId;
            }

            if (WindowsActionCatalog.Get(HyperShiftAssignments[button]).MouseButton == button)
            {
                HyperShiftAssignments[button] = WindowsActionCatalog.PassthroughId;
            }
        }

        PrimaryAssignments[MouseButtonId.TiltLeft] =
            RemoveMomentaryHyperShift(PrimaryAssignments[MouseButtonId.TiltLeft]);
        PrimaryAssignments[MouseButtonId.TiltRight] =
            RemoveMomentaryHyperShift(PrimaryAssignments[MouseButtonId.TiltRight]);

        foreach (var button in Enum.GetValues<MouseButtonId>())
        {
            if (HyperShiftAssignments[button] == WindowsActionCatalog.HyperShiftId)
            {
                HyperShiftAssignments[button] = WindowsActionCatalog.PassthroughId;
            }

            if (PrimaryAssignments[button] == WindowsActionCatalog.HyperShiftId)
            {
                HyperShiftAssignments[button] = WindowsActionCatalog.PassthroughId;
            }
        }
    }

    private static int RoundDpi(int dpi)
    {
        return (int)Math.Round(dpi / 100d, MidpointRounding.AwayFromZero) * 100;
    }

    private static string NormalizeAction(
        IReadOnlyDictionary<MouseButtonId, string> assignments,
        MouseButtonId button)
    {
        return assignments.TryGetValue(button, out var actionId)
            && WindowsActionCatalog.TryGet(actionId, out _)
                ? actionId
                : WindowsActionCatalog.PassthroughId;
    }

    private static string RemoveMomentaryHyperShift(string actionId)
    {
        return actionId == WindowsActionCatalog.HyperShiftId
            ? WindowsActionCatalog.PassthroughId
            : actionId;
    }
}
