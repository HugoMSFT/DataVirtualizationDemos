using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.Protocol;

namespace ProClickConfigurator.Device;

public sealed class ProClickMiniDevice : IDisposable
{
    public const ushort VendorId = 0x1532;
    public const ushort ProductId = 0x009A;
    public const int MinimumDpi = 100;
    public const int MaximumDpi = 12000;
    public const int MaximumDpiStages = 5;

    private const byte TransactionId = 0x1F;
    private const int WirelessDelayMilliseconds = 60;
    private const int MaximumResponseAttempts = 10;
    private const int MaximumRequestAttempts = 3;
    private readonly WindowsHidDevice _device;
    private readonly object _transactionLock = new();

    private ProClickMiniDevice(WindowsHidDevice device)
    {
        _device = device;
    }

    public static ProClickMiniDevice? TryConnect()
    {
        var device = WindowsHidDevice.Find(VendorId, ProductId);
        return device is null ? null : new ProClickMiniDevice(device);
    }

    public Task<ProClickMiniSnapshot> ReadSnapshotAsync(CancellationToken cancellationToken = default)
    {
        return Task.Run(ReadSnapshot, cancellationToken);
    }

    public Task<ProClickMiniSnapshot> ApplySettingsAsync(
        ProClickMiniSettings settings,
        OnboardButtonProfile? buttonProfile = null,
        CancellationToken cancellationToken = default)
    {
        ValidateSettings(settings);
        IReadOnlyList<PendingButtonWrite> buttonWrites = buttonProfile is null
            ? []
            : BuildButtonWrites(buttonProfile);
        return Task.Run(
            () =>
            {
                SetDpiStages(settings.DpiStages, settings.ActiveDpiStage);
                SetCurrentDpi(settings.CurrentDpi);
                SetPollingRate(settings.PollingRateHz);
                SetIdleTime(settings.IdleTimeSeconds);
                SetLowBatteryThreshold(settings.LowBatteryThresholdPercent);
                SetOnboardButtonProfile(buttonWrites);
                return ReadSnapshot();
            },
            cancellationToken);
    }

    public Task<int> ReadBatteryPercentAsync(CancellationToken cancellationToken = default)
    {
        return Task.Run(ReadBatteryPercent, cancellationToken);
    }

    public void Dispose()
    {
        lock (_transactionLock)
        {
            _device.Dispose();
        }
    }

    private ProClickMiniSnapshot ReadSnapshot()
    {
        var currentDpi = ReadCurrentDpi();
        var (stages, activeStage) = ReadDpiStages();
        var charging = TryReadChargingStatus();
        OnboardButtonProfile? buttonProfile = null;
        string? buttonReadError = null;
        try
        {
            buttonProfile = ReadOnboardButtonProfile();
        }
        catch (RazerProtocolException exception)
        {
            buttonReadError = exception.Message;
        }

        return new ProClickMiniSnapshot(
            currentDpi.X,
            currentDpi.Y,
            stages,
            activeStage,
            ReadPollingRate(),
            ReadBatteryPercent(),
            charging,
            ReadIdleTime(),
            ReadLowBatteryThreshold(),
            ReadFirmwareVersion(),
            buttonProfile,
            buttonReadError);
    }

    private DpiStage ReadCurrentDpi()
    {
        var response = Execute(0x04, 0x85, 0x07, [0x01]);
        var arguments = response.Arguments;
        return new DpiStage(
            ReadUInt16BigEndian(arguments, 1),
            ReadUInt16BigEndian(arguments, 3));
    }

    private (IReadOnlyList<DpiStage> Stages, int ActiveStage) ReadDpiStages()
    {
        var response = Execute(0x04, 0x86, 0x26, [0x01]);
        var arguments = response.Arguments;
        var activeStage = arguments[1];
        var count = Math.Min((int)arguments[2], MaximumDpiStages);
        var stages = new List<DpiStage>(count);

        for (var index = 0; index < count; index++)
        {
            var offset = 3 + (index * 7);
            if (offset + 6 >= arguments.Length)
            {
                break;
            }

            stages.Add(new DpiStage(
                ReadUInt16BigEndian(arguments, offset + 1),
                ReadUInt16BigEndian(arguments, offset + 3)));
        }

        if (stages.Count == 0)
        {
            var current = ReadCurrentDpi();
            stages.Add(current);
            activeStage = 1;
        }

        return (stages, Math.Clamp(activeStage, 1, stages.Count));
    }

    private int ReadPollingRate()
    {
        var response = Execute(0x00, 0x85, 0x01);
        return response.Arguments[0] switch
        {
            0x01 => 1000,
            0x02 => 500,
            0x08 => 125,
            var value => throw new RazerProtocolException(
                $"The mouse returned an unknown polling-rate code: 0x{value:X2}."),
        };
    }

    private int ReadBatteryPercent()
    {
        var response = Execute(0x07, 0x80, 0x02);
        return (int)Math.Round(response.Arguments[1] / 255d * 100d);
    }

    private bool? TryReadChargingStatus()
    {
        try
        {
            var response = Execute(0x07, 0x84, 0x02);
            return response.Arguments[1] != 0;
        }
        catch (RazerProtocolException exception) when (
            exception.Status == RazerCommandStatus.NotSupported)
        {
            return null;
        }
    }

    private int ReadIdleTime()
    {
        var response = Execute(0x07, 0x83, 0x02);
        return ReadUInt16BigEndian(response.Arguments, 0);
    }

    private int ReadLowBatteryThreshold()
    {
        var response = Execute(0x07, 0x81, 0x01);
        return (int)Math.Round(response.Arguments[0] / 255d * 100d);
    }

    private Version ReadFirmwareVersion()
    {
        var response = Execute(0x00, 0x81, 0x02);
        return new Version(response.Arguments[0], response.Arguments[1]);
    }

    private void SetCurrentDpi(int dpi)
    {
        Execute(
            0x04,
            0x05,
            0x07,
            [
                0x01,
                (byte)(dpi >> 8),
                (byte)dpi,
                (byte)(dpi >> 8),
                (byte)dpi,
                0x00,
                0x00,
            ]);
    }

    private void SetDpiStages(IReadOnlyList<DpiStage> stages, int activeStage)
    {
        var arguments = new byte[0x26];
        arguments[0] = 0x01;
        arguments[1] = (byte)activeStage;
        arguments[2] = (byte)stages.Count;

        var offset = 3;
        for (var index = 0; index < stages.Count; index++)
        {
            var stage = stages[index];
            arguments[offset++] = (byte)index;
            arguments[offset++] = (byte)(stage.X >> 8);
            arguments[offset++] = (byte)stage.X;
            arguments[offset++] = (byte)(stage.Y >> 8);
            arguments[offset++] = (byte)stage.Y;
            arguments[offset++] = 0x00;
            arguments[offset++] = 0x00;
        }

        Execute(0x04, 0x06, 0x26, arguments);
    }

    private void SetPollingRate(int pollingRateHz)
    {
        var code = pollingRateHz switch
        {
            1000 => (byte)0x01,
            500 => (byte)0x02,
            125 => (byte)0x08,
            _ => throw new ArgumentOutOfRangeException(nameof(pollingRateHz)),
        };

        Execute(0x00, 0x05, 0x01, [code]);
    }

    private void SetIdleTime(int idleTimeSeconds)
    {
        Execute(
            0x07,
            0x03,
            0x02,
            [(byte)(idleTimeSeconds >> 8), (byte)idleTimeSeconds]);
    }

    private void SetLowBatteryThreshold(int percentage)
    {
        var rawValue = Math.Clamp(
            (int)Math.Round(percentage / 100d * 255d),
            0x0C,
            0x3F);
        Execute(0x07, 0x01, 0x01, [(byte)rawValue]);
    }

    private OnboardButtonProfile ReadOnboardButtonProfile()
    {
        var primary = new Dictionary<MouseButtonId, string>();
        var hyperShift = new Dictionary<MouseButtonId, string>();

        foreach (var button in OnboardButtonAssignmentCodec.Buttons)
        {
            primary[button] = OnboardButtonAssignmentCodec.Decode(
                button,
                ReadOnboardButtonAssignment(button, isHyperShift: false));
            hyperShift[button] = OnboardButtonAssignmentCodec.Decode(
                button,
                ReadOnboardButtonAssignment(button, isHyperShift: true));
            if (hyperShift[button] == WindowsActionCatalog.HyperShiftId)
            {
                hyperShift[button] = WindowsActionCatalog.PassthroughId;
            }
        }

        return new OnboardButtonProfile(primary, hyperShift);
    }

    private OnboardButtonRecord ReadOnboardButtonAssignment(
        MouseButtonId button,
        bool isHyperShift)
    {
        const byte profileId = 0x01;
        var buttonId = OnboardButtonAssignmentCodec.GetDeviceButtonId(button);
        var response = Execute(
            0x02,
            0x8C,
            0x50,
            [profileId, buttonId, isHyperShift ? (byte)0x01 : (byte)0x00],
            candidate =>
            {
                var arguments = candidate.Arguments;
                return arguments.Length >= 2
                    && arguments[0] == profileId
                    && arguments[1] == buttonId;
            });
        var arguments = response.Arguments;
        if (arguments.Length < 5 || arguments[4] > 5 || arguments.Length < 5 + arguments[4])
        {
            throw new RazerProtocolException(
                $"The mouse returned an invalid assignment record for {button}.");
        }

        return new OnboardButtonRecord(
            arguments[3],
            arguments.Slice(5, arguments[4]).ToArray());
    }

    private static IReadOnlyList<PendingButtonWrite> BuildButtonWrites(
        OnboardButtonProfile buttonProfile)
    {
        var writes = new List<PendingButtonWrite>(OnboardButtonAssignmentCodec.Buttons.Count * 2);
        foreach (var button in OnboardButtonAssignmentCodec.Buttons)
        {
            if (!buttonProfile.PrimaryAssignments.TryGetValue(button, out var primaryAction)
                || !buttonProfile.HyperShiftAssignments.TryGetValue(button, out var hyperShiftAction))
            {
                throw new InvalidOperationException($"The onboard profile is missing {button}.");
            }

            writes.Add(new PendingButtonWrite(
                button,
                IsHyperShift: false,
                OnboardButtonAssignmentCodec.Encode(button, primaryAction)));
            writes.Add(new PendingButtonWrite(
                button,
                IsHyperShift: true,
                OnboardButtonAssignmentCodec.Encode(
                    button,
                    primaryAction == WindowsActionCatalog.HyperShiftId
                        ? WindowsActionCatalog.HyperShiftId
                        : hyperShiftAction)));
        }

        return writes;
    }

    private void SetOnboardButtonProfile(IReadOnlyList<PendingButtonWrite> writes)
    {
        const byte profileId = 0x01;
        foreach (var write in writes)
        {
            var buttonId = OnboardButtonAssignmentCodec.GetDeviceButtonId(write.Button);
            var arguments = new byte[10];
            arguments[0] = profileId;
            arguments[1] = buttonId;
            arguments[2] = write.IsHyperShift ? (byte)0x01 : (byte)0x00;
            arguments[3] = write.Record.FunctionId;
            arguments[4] = checked((byte)write.Record.Data.Count);
            write.Record.Data.ToArray().CopyTo(arguments, 5);

            Execute(0x02, 0x0C, 0x50, arguments);
            var verified = ReadOnboardButtonAssignment(write.Button, write.IsHyperShift);
            if (!OnboardButtonAssignmentCodec.RecordsEqual(write.Record, verified))
            {
                throw new RazerProtocolException(
                    $"The mouse did not retain the {write.Button} "
                    + $"{(write.IsHyperShift ? "HyperShift" : "primary")} assignment.");
            }
        }
    }

    private RazerReport Execute(
        byte commandClass,
        byte commandId,
        byte dataSize,
        ReadOnlySpan<byte> arguments = default,
        Func<RazerReport, bool>? responseValidator = null)
    {
        lock (_transactionLock)
        {
            var request = RazerReport.Create(
                TransactionId,
                commandClass,
                commandId,
                dataSize,
                arguments);

            for (var requestAttempt = 0; requestAttempt < MaximumRequestAttempts; requestAttempt++)
            {
                _device.SetFeature(request.ToArray());

                for (var responseAttempt = 0; responseAttempt < MaximumResponseAttempts; responseAttempt++)
                {
                    Thread.Sleep(WirelessDelayMilliseconds);
                    var response = RazerReport.Parse(_device.GetFeature());
                    if (response.CommandClass != commandClass || response.CommandId != commandId)
                    {
                        continue;
                    }

                    switch (response.Status)
                    {
                        case RazerCommandStatus.Successful:
                            if (responseValidator is not null && !responseValidator(response))
                            {
                                continue;
                            }

                            return response;
                        case RazerCommandStatus.Busy:
                        case RazerCommandStatus.New:
                            continue;
                        case RazerCommandStatus.Timeout:
                            responseAttempt = MaximumResponseAttempts;
                            break;
                        case RazerCommandStatus.Failure:
                            throw new RazerProtocolException(
                                "The mouse reported that the command failed.",
                                response.Status);
                        case RazerCommandStatus.NotSupported:
                            throw new RazerProtocolException(
                                "The mouse does not support this command.",
                                response.Status);
                    }
                }
            }

            throw new RazerProtocolException(
                "The receiver is present, but the mouse is not responding.",
                RazerCommandStatus.Timeout);
        }
    }

    private static int ReadUInt16BigEndian(ReadOnlySpan<byte> bytes, int offset)
    {
        return (bytes[offset] << 8) | bytes[offset + 1];
    }

    private static void ValidateSettings(ProClickMiniSettings settings)
    {
        if (settings.CurrentDpi is < MinimumDpi or > MaximumDpi)
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "DPI must be between 100 and 12000.");
        }

        if (settings.DpiStages.Count is < 1 or > MaximumDpiStages)
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "The mouse supports one to five DPI stages.");
        }

        if (settings.DpiStages.Any(
                stage => stage.X is < MinimumDpi or > MaximumDpi
                    || stage.Y is < MinimumDpi or > MaximumDpi))
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "Every DPI stage must be between 100 and 12000.");
        }

        if (settings.ActiveDpiStage < 1 || settings.ActiveDpiStage > settings.DpiStages.Count)
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "The active DPI stage does not exist.");
        }

        if (settings.PollingRateHz is not (125 or 500 or 1000))
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "Polling rate must be 125, 500, or 1000 Hz.");
        }

        if (settings.IdleTimeSeconds is < 60 or > 900)
        {
            throw new ArgumentOutOfRangeException(nameof(settings), "Idle time must be between 60 and 900 seconds.");
        }

        if (settings.LowBatteryThresholdPercent is < 5 or > 25)
        {
            throw new ArgumentOutOfRangeException(
                nameof(settings),
                "Low-battery threshold must be between 5 and 25 percent.");
        }
    }

    private sealed record PendingButtonWrite(
        MouseButtonId Button,
        bool IsHyperShift,
        OnboardButtonRecord Record);
}
