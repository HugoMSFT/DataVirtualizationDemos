using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.Protocol;

namespace ProClickConfigurator.Tests;

public sealed class OnboardButtonAssignmentCodecTests
{
    [Theory]
    [InlineData(MouseButtonId.Left, 0x01, "01", WindowsActionCatalog.PassthroughId)]
    [InlineData(MouseButtonId.Back, 0x01, "05", "mouse.forward")]
    [InlineData(MouseButtonId.Forward, 0x0C, "01", WindowsActionCatalog.HyperShiftId)]
    [InlineData(MouseButtonId.Middle, 0x0A, "00CD", "media.play-pause")]
    [InlineData(MouseButtonId.TiltLeft, 0x0A, "00E9", "media.volume-up")]
    [InlineData(MouseButtonId.TiltRight, 0x0A, "00EA", "media.volume-down")]
    public void DecodesCapturedProClickMiniAssignments(
        MouseButtonId sourceButton,
        byte functionId,
        string dataHex,
        string expectedActionId)
    {
        var actionId = OnboardButtonAssignmentCodec.Decode(
            sourceButton,
            new OnboardButtonRecord(functionId, Convert.FromHexString(dataHex)));

        Assert.Equal(expectedActionId, actionId);
    }

    [Fact]
    public void EncodesEveryCatalogActionForPressableButton()
    {
        foreach (var action in WindowsActionCatalog.All)
        {
            var record = OnboardButtonAssignmentCodec.Encode(MouseButtonId.Back, action.Id);

            Assert.InRange(record.Data.Count, 0, 5);
        }
    }

    [Fact]
    public void EncodesKeyboardChordAsModifierAndHidUsage()
    {
        var record = OnboardButtonAssignmentCodec.Encode(MouseButtonId.Back, "edit.copy");

        Assert.Equal(0x02, record.FunctionId);
        Assert.Equal([0x01, 0x06], record.Data);
    }

    [Fact]
    public void EncodesMediaUsageInObservedDeviceByteOrder()
    {
        var record = OnboardButtonAssignmentCodec.Encode(
            MouseButtonId.TiltLeft,
            "media.volume-up");

        Assert.Equal(0x0A, record.FunctionId);
        Assert.Equal([0x00, 0xE9], record.Data);
    }

    [Fact]
    public void RejectsHyperShiftModifierOnMomentaryTiltControl()
    {
        Assert.Throws<InvalidOperationException>(
            () => OnboardButtonAssignmentCodec.Encode(
                MouseButtonId.TiltLeft,
                WindowsActionCatalog.HyperShiftId));
    }
}
