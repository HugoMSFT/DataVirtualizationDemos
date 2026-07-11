using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.Profiles;

namespace ProClickConfigurator.Tests;

public sealed class MouseProfileTests
{
    [Fact]
    public void DefaultProfilePassesThroughEveryButtonOnBothLayers()
    {
        var profile = MouseProfile.CreateDefault();

        foreach (var button in Enum.GetValues<MouseButtonId>())
        {
            Assert.Equal(WindowsActionCatalog.PassthroughId, profile.PrimaryAssignments[button]);
            Assert.Equal(WindowsActionCatalog.PassthroughId, profile.HyperShiftAssignments[button]);
        }
    }

    [Fact]
    public void NormalizeConstrainsHardwareValuesAndInvalidActions()
    {
        var profile = MouseProfile.CreateDefault();
        profile.CurrentDpi = 12_099;
        profile.DpiStages = [49, 855, 12_900, 400, 500, 600];
        profile.ActiveDpiStage = 10;
        profile.PollingRateHz = 250;
        profile.IdleTimeSeconds = 2_000;
        profile.LowBatteryThresholdPercent = 90;
        profile.PrimaryAssignments[MouseButtonId.Left] = "media.play-pause";
        profile.PrimaryAssignments[MouseButtonId.Right] = "mouse.right";
        profile.PrimaryAssignments[MouseButtonId.TiltLeft] = WindowsActionCatalog.HyperShiftId;
        profile.PrimaryAssignments[MouseButtonId.Back] = WindowsActionCatalog.HyperShiftId;
        profile.HyperShiftAssignments[MouseButtonId.Back] = "media.play-pause";
        profile.HyperShiftAssignments[MouseButtonId.Forward] = "mouse.forward";
        profile.HyperShiftAssignments[MouseButtonId.Right] = WindowsActionCatalog.HyperShiftId;

        profile.Normalize();

        Assert.Equal(12_000, profile.CurrentDpi);
        Assert.Equal([100, 900, 12_000, 400, 500], profile.DpiStages);
        Assert.Equal(5, profile.ActiveDpiStage);
        Assert.Equal(1000, profile.PollingRateHz);
        Assert.Equal(900, profile.IdleTimeSeconds);
        Assert.Equal(25, profile.LowBatteryThresholdPercent);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.PrimaryAssignments[MouseButtonId.Left]);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.PrimaryAssignments[MouseButtonId.Right]);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.PrimaryAssignments[MouseButtonId.TiltLeft]);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.HyperShiftAssignments[MouseButtonId.Back]);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.HyperShiftAssignments[MouseButtonId.Forward]);
        Assert.Equal(WindowsActionCatalog.PassthroughId, profile.HyperShiftAssignments[MouseButtonId.Right]);
    }

    [Fact]
    public void NormalizeRejectsNewerSchema()
    {
        var profile = MouseProfile.CreateDefault();
        profile.SchemaVersion = MouseProfile.CurrentSchemaVersion + 1;

        Assert.Throws<InvalidDataException>(profile.Normalize);
    }
}
