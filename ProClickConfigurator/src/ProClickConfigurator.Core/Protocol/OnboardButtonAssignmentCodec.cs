using ProClickConfigurator.Core.Models;

namespace ProClickConfigurator.Core.Protocol;

public sealed record OnboardButtonRecord(byte FunctionId, IReadOnlyList<byte> Data);

public static class OnboardButtonAssignmentCodec
{
    private const byte DisabledFunction = 0x00;
    private const byte MouseButtonFunction = 0x01;
    private const byte KeyboardFunction = 0x02;
    private const byte MediaFunction = 0x0A;
    private const byte HyperShiftFunction = 0x0C;

    private static readonly IReadOnlyDictionary<MouseButtonId, byte> DeviceButtonIds =
        new Dictionary<MouseButtonId, byte>
        {
            [MouseButtonId.Left] = 0x01,
            [MouseButtonId.Right] = 0x02,
            [MouseButtonId.Middle] = 0x03,
            [MouseButtonId.Back] = 0x04,
            [MouseButtonId.Forward] = 0x05,
            [MouseButtonId.TiltLeft] = 0x09,
            [MouseButtonId.TiltRight] = 0x0A,
        };

    private static readonly IReadOnlyDictionary<ushort, ushort> MediaUsages =
        new Dictionary<ushort, ushort>
        {
            [0xAD] = 0x00E2,
            [0xAE] = 0x00EA,
            [0xAF] = 0x00E9,
            [0xB0] = 0x00B5,
            [0xB1] = 0x00B6,
            [0xB2] = 0x00B7,
            [0xB3] = 0x00CD,
        };

    public static IReadOnlyList<MouseButtonId> Buttons { get; } =
        Enum.GetValues<MouseButtonId>();

    public static byte GetDeviceButtonId(MouseButtonId button)
    {
        return DeviceButtonIds.TryGetValue(button, out var buttonId)
            ? buttonId
            : throw new ArgumentOutOfRangeException(nameof(button));
    }

    public static string Decode(MouseButtonId sourceButton, OnboardButtonRecord record)
    {
        foreach (var action in WindowsActionCatalog.All)
        {
            if (TryEncode(sourceButton, action.Id, out var candidate)
                && RecordsEqual(candidate, record))
            {
                return action.Id;
            }
        }

        throw new RazerProtocolException(
            $"Button {sourceButton} uses an unsupported onboard action "
            + $"(function 0x{record.FunctionId:X2}, data {Convert.ToHexString([.. record.Data])}).");
    }

    public static OnboardButtonRecord Encode(MouseButtonId sourceButton, string actionId)
    {
        return TryEncode(sourceButton, actionId, out var record)
            ? record
            : throw new InvalidOperationException(
                $"Action '{actionId}' cannot be stored onboard for {sourceButton}.");
    }

    public static bool RecordsEqual(OnboardButtonRecord left, OnboardButtonRecord right)
    {
        return left.FunctionId == right.FunctionId
            && left.Data.SequenceEqual(right.Data);
    }

    private static bool TryEncode(
        MouseButtonId sourceButton,
        string actionId,
        out OnboardButtonRecord record)
    {
        record = new OnboardButtonRecord(DisabledFunction, []);
        if (!WindowsActionCatalog.TryGet(actionId, out var action) || action is null)
        {
            return false;
        }

        switch (action.Kind)
        {
            case WindowsActionKind.Passthrough:
                record = MouseButton(sourceButton);
                return true;
            case WindowsActionKind.Disabled:
                record = new OnboardButtonRecord(DisabledFunction, []);
                return true;
            case WindowsActionKind.HyperShift:
                if (sourceButton is MouseButtonId.TiltLeft or MouseButtonId.TiltRight)
                {
                    return false;
                }

                record = new OnboardButtonRecord(HyperShiftFunction, [0x01]);
                return true;
            case WindowsActionKind.MouseButton when action.MouseButton is { } targetButton:
                record = MouseButton(targetButton);
                return true;
            case WindowsActionKind.KeyboardShortcut when action.VirtualKeys is { } keys:
                return TryEncodeKeyboard(keys, out record);
            default:
                return false;
        }
    }

    private static OnboardButtonRecord MouseButton(MouseButtonId targetButton)
    {
        return new OnboardButtonRecord(
            MouseButtonFunction,
            [GetDeviceButtonId(targetButton)]);
    }

    private static bool TryEncodeKeyboard(
        IReadOnlyList<ushort> virtualKeys,
        out OnboardButtonRecord record)
    {
        record = new OnboardButtonRecord(DisabledFunction, []);
        if (virtualKeys.Count == 1 && MediaUsages.TryGetValue(virtualKeys[0], out var mediaUsage))
        {
            record = new OnboardButtonRecord(
                MediaFunction,
                [(byte)(mediaUsage >> 8), (byte)mediaUsage]);
            return true;
        }

        byte modifierBits = 0;
        ushort? key = null;
        foreach (var virtualKey in virtualKeys)
        {
            var modifier = virtualKey switch
            {
                0x11 => (byte)0x01,
                0x10 => (byte)0x02,
                0x12 => (byte)0x04,
                0x5B => (byte)0x08,
                _ => (byte)0x00,
            };

            if (modifier != 0)
            {
                modifierBits |= modifier;
            }
            else if (key is null)
            {
                key = virtualKey;
            }
            else
            {
                return false;
            }
        }

        if (key is null || !TryGetHidUsage(key.Value, out var hidUsage))
        {
            return false;
        }

        record = new OnboardButtonRecord(KeyboardFunction, [modifierBits, hidUsage]);
        return true;
    }

    private static bool TryGetHidUsage(ushort virtualKey, out byte hidUsage)
    {
        if (virtualKey is >= 0x41 and <= 0x5A)
        {
            hidUsage = (byte)(0x04 + virtualKey - 0x41);
            return true;
        }

        if (virtualKey is >= 0x31 and <= 0x39)
        {
            hidUsage = (byte)(0x1E + virtualKey - 0x31);
            return true;
        }

        hidUsage = virtualKey switch
        {
            0x30 => 0x27,
            0x08 => 0x2A,
            0x09 => 0x2B,
            0x0D => 0x28,
            0x1B => 0x29,
            0x20 => 0x2C,
            0x21 => 0x4B,
            0x22 => 0x4E,
            0x23 => 0x4D,
            0x24 => 0x4A,
            0x25 => 0x50,
            0x26 => 0x52,
            0x27 => 0x4F,
            0x28 => 0x51,
            0x2E => 0x4C,
            0x73 => 0x3D,
            0xBE => 0x37,
            _ => 0x00,
        };
        return hidUsage != 0;
    }
}
