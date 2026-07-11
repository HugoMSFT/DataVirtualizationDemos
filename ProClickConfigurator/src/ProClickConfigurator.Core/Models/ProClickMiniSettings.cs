namespace ProClickConfigurator.Core.Models;

public sealed record ProClickMiniSettings(
    int CurrentDpi,
    IReadOnlyList<DpiStage> DpiStages,
    int ActiveDpiStage,
    int PollingRateHz,
    int IdleTimeSeconds,
    int LowBatteryThresholdPercent);
