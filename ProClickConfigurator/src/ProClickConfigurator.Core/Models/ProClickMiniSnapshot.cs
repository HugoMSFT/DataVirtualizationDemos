namespace ProClickConfigurator.Core.Models;

public sealed record ProClickMiniSnapshot(
    int CurrentDpiX,
    int CurrentDpiY,
    IReadOnlyList<DpiStage> DpiStages,
    int ActiveDpiStage,
    int PollingRateHz,
    int BatteryPercent,
    bool? IsCharging,
    int IdleTimeSeconds,
    int LowBatteryThresholdPercent,
    Version FirmwareVersion,
    OnboardButtonProfile? OnboardButtonProfile = null,
    string? OnboardButtonReadError = null)
{
    public ProClickMiniSettings ToSettings()
    {
        return new ProClickMiniSettings(
            CurrentDpiX,
            DpiStages,
            ActiveDpiStage,
            PollingRateHz,
            IdleTimeSeconds,
            LowBatteryThresholdPercent);
    }
}
