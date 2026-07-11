using System.Runtime.InteropServices;

namespace ProClickConfigurator.Core.Device;

internal sealed class MacHidDevice : IRazerHidDevice
{
    private const int FeatureReportType = 2;
    private const int ExpectedFeatureLength = 90;
    private nint _manager;
    private nint _device;

    private MacHidDevice(nint manager, nint device)
    {
        _manager = manager;
        _device = device;
    }

    internal static MacHidDevice? Find(ushort vendorId, ushort productId)
    {
        var manager = MacNativeMethods.IOHIDManagerCreate(0, 0);
        if (manager == 0)
        {
            throw new IOException("macOS could not create an IOKit HID manager.");
        }

        var runLoop = MacNativeMethods.CFRunLoopGetCurrent();
        var runLoopMode = MacNativeMethods.CFStringCreateWithCString(
            0,
            "kCFRunLoopDefaultMode",
            MacNativeMethods.CfStringEncodingUtf8);
        if (runLoop == 0 || runLoopMode == 0)
        {
            if (runLoopMode != 0)
            {
                MacNativeMethods.CFRelease(runLoopMode);
            }

            MacNativeMethods.CFRelease(manager);
            throw new IOException("macOS could not initialize HID device discovery.");
        }

        MacNativeMethods.IOHIDManagerSetDeviceMatching(manager, 0);
        MacNativeMethods.IOHIDManagerScheduleWithRunLoop(manager, runLoop, runLoopMode);
        int managerOpen;
        nint deviceSet = 0;
        try
        {
            managerOpen = MacNativeMethods.IOHIDManagerOpen(manager, 0);
            if (managerOpen == 0)
            {
                PumpPendingHidEvents(runLoopMode);
                deviceSet = MacNativeMethods.IOHIDManagerCopyDevices(manager);
            }
        }
        finally
        {
            MacNativeMethods.IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, runLoopMode);
            MacNativeMethods.CFRelease(runLoopMode);
        }

        if (managerOpen != 0)
        {
            MacNativeMethods.CFRelease(manager);
            throw CreateIoException("macOS could not open the IOKit HID manager", managerOpen);
        }

        if (deviceSet == 0)
        {
            CloseManager(manager);
            return null;
        }

        var keepManagerOpen = false;
        try
        {
            var count = checked((int)MacNativeMethods.CFSetGetCount(deviceSet));
            var devices = new nint[count];
            MacNativeMethods.CFSetGetValues(deviceSet, devices);

            var candidates = devices
                .Where(device => ReadIntProperty(device, "VendorID") == vendorId)
                .Where(device => ReadIntProperty(device, "ProductID") == productId)
                .Where(device => ReadIntProperty(device, "MaxFeatureReportSize") >= ExpectedFeatureLength)
                .OrderByDescending(device =>
                    ReadIntProperty(device, "PrimaryUsagePage") == 0x01
                    && ReadIntProperty(device, "PrimaryUsage") == 0x02)
                .ToArray();

            var lastOpenError = 0;
            foreach (var device in candidates)
            {
                var openResult = MacNativeMethods.IOHIDDeviceOpen(device, 0);
                if (openResult == 0)
                {
                    MacNativeMethods.CFRetain(device);
                    keepManagerOpen = true;
                    return new MacHidDevice(manager, device);
                }

                lastOpenError = openResult;
            }

            if (candidates.Length > 0)
            {
                throw new UnauthorizedAccessException(
                    "macOS found the Pro Click Mini receiver but could not open its HID interface "
                    + $"(IOReturn 0x{unchecked((uint)lastOpenError):X8}). "
                    + "Allow the app in System Settings > Privacy & Security > Input Monitoring.");
            }

            return null;
        }
        finally
        {
            MacNativeMethods.CFRelease(deviceSet);
            if (!keepManagerOpen)
            {
                CloseManager(manager);
            }
        }
    }

    public void SetFeature(ReadOnlySpan<byte> report)
    {
        ObjectDisposedException.ThrowIf(_device == 0, this);
        if (report.Length != ExpectedFeatureLength)
        {
            throw new ArgumentException(
                $"Expected a {ExpectedFeatureLength}-byte feature report.",
                nameof(report));
        }

        var bytes = report.ToArray();
        var result = MacNativeMethods.IOHIDDeviceSetReport(
            _device,
            FeatureReportType,
            0,
            bytes,
            bytes.Length);
        if (result != 0)
        {
            throw CreateIoException("macOS rejected the HID feature report", result);
        }
    }

    public byte[] GetFeature()
    {
        ObjectDisposedException.ThrowIf(_device == 0, this);
        var bytes = new byte[ExpectedFeatureLength];
        nint length = bytes.Length;
        var result = MacNativeMethods.IOHIDDeviceGetReport(
            _device,
            FeatureReportType,
            0,
            bytes,
            ref length);
        if (result != 0)
        {
            throw CreateIoException("macOS could not read a HID feature report", result);
        }

        if (length != ExpectedFeatureLength)
        {
            throw new IOException(
                $"The receiver returned a {length}-byte feature report; "
                + $"{ExpectedFeatureLength} bytes were expected.");
        }

        return bytes;
    }

    public void Dispose()
    {
        if (_device != 0)
        {
            MacNativeMethods.IOHIDDeviceClose(_device, 0);
            MacNativeMethods.CFRelease(_device);
            _device = 0;
        }

        if (_manager != 0)
        {
            CloseManager(_manager);
            _manager = 0;
        }
    }

    private static int? ReadIntProperty(nint device, string propertyName)
    {
        var key = MacNativeMethods.CFStringCreateWithCString(
            0,
            propertyName,
            MacNativeMethods.CfStringEncodingUtf8);
        if (key == 0)
        {
            throw new IOException($"macOS could not create the '{propertyName}' HID property key.");
        }

        try
        {
            var value = MacNativeMethods.IOHIDDeviceGetProperty(device, key);
            if (value == 0
                || MacNativeMethods.CFGetTypeID(value) != MacNativeMethods.CFNumberGetTypeID()
                || !MacNativeMethods.CFNumberGetValue(
                    value,
                    MacNativeMethods.CfNumberSInt32Type,
                    out var number))
            {
                return null;
            }

            return number;
        }
        finally
        {
            MacNativeMethods.CFRelease(key);
        }
    }

    private static IOException CreateIoException(string message, int ioReturn)
    {
        return new IOException($"{message} (IOReturn 0x{unchecked((uint)ioReturn):X8}).");
    }

    private static void PumpPendingHidEvents(nint runLoopMode)
    {
        const int runFinished = 1;
        const int runTimedOut = 3;
        for (var attempt = 0; attempt < 32; attempt++)
        {
            var result = MacNativeMethods.CFRunLoopRunInMode(
                runLoopMode,
                0.001,
                returnAfterSourceHandled: false);
            if (result is runFinished or runTimedOut)
            {
                return;
            }
        }
    }

    private static void CloseManager(nint manager)
    {
        MacNativeMethods.IOHIDManagerClose(manager, 0);
        MacNativeMethods.CFRelease(manager);
    }
}

internal static class MacNativeMethods
{
    private const string IOKit =
        "/System/Library/Frameworks/IOKit.framework/IOKit";
    private const string CoreFoundation =
        "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";

    internal const uint CfStringEncodingUtf8 = 0x08000100;
    internal const nint CfNumberSInt32Type = 3;

    [DllImport(IOKit)]
    internal static extern nint IOHIDManagerCreate(nint allocator, uint options);

    [DllImport(IOKit)]
    internal static extern void IOHIDManagerSetDeviceMatching(nint manager, nint matching);

    [DllImport(IOKit)]
    internal static extern void IOHIDManagerScheduleWithRunLoop(
        nint manager,
        nint runLoop,
        nint runLoopMode);

    [DllImport(IOKit)]
    internal static extern void IOHIDManagerUnscheduleFromRunLoop(
        nint manager,
        nint runLoop,
        nint runLoopMode);

    [DllImport(IOKit)]
    internal static extern int IOHIDManagerOpen(nint manager, uint options);

    [DllImport(IOKit)]
    internal static extern int IOHIDManagerClose(nint manager, uint options);

    [DllImport(IOKit)]
    internal static extern nint IOHIDManagerCopyDevices(nint manager);

    [DllImport(IOKit)]
    internal static extern int IOHIDDeviceOpen(nint device, uint options);

    [DllImport(IOKit)]
    internal static extern int IOHIDDeviceClose(nint device, uint options);

    [DllImport(IOKit)]
    internal static extern nint IOHIDDeviceGetProperty(nint device, nint key);

    [DllImport(IOKit)]
    internal static extern int IOHIDDeviceSetReport(
        nint device,
        int reportType,
        nint reportId,
        byte[] report,
        nint reportLength);

    [DllImport(IOKit)]
    internal static extern int IOHIDDeviceGetReport(
        nint device,
        int reportType,
        nint reportId,
        byte[] report,
        ref nint reportLength);

    [DllImport(CoreFoundation)]
    internal static extern void CFRelease(nint value);

    [DllImport(CoreFoundation)]
    internal static extern nint CFRetain(nint value);

    [DllImport(CoreFoundation)]
    internal static extern nint CFSetGetCount(nint set);

    [DllImport(CoreFoundation)]
    internal static extern void CFSetGetValues(nint set, nint[] values);

    [DllImport(CoreFoundation)]
    internal static extern nint CFStringCreateWithCString(
        nint allocator,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string value,
        uint encoding);

    [DllImport(CoreFoundation)]
    internal static extern nint CFRunLoopGetCurrent();

    [DllImport(CoreFoundation)]
    internal static extern int CFRunLoopRunInMode(
        nint mode,
        double seconds,
        [MarshalAs(UnmanagedType.I1)] bool returnAfterSourceHandled);

    [DllImport(CoreFoundation)]
    internal static extern nuint CFGetTypeID(nint value);

    [DllImport(CoreFoundation)]
    internal static extern nuint CFNumberGetTypeID();

    [DllImport(CoreFoundation)]
    [return: MarshalAs(UnmanagedType.I1)]
    internal static extern bool CFNumberGetValue(
        nint number,
        nint numberType,
        out int value);
}
