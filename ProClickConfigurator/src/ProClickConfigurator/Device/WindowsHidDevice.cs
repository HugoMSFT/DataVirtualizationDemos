using Microsoft.Win32.SafeHandles;
using ProClickConfigurator.Core.Protocol;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace ProClickConfigurator.Device;

internal sealed class WindowsHidDevice : IDisposable
{
    private readonly SafeFileHandle _handle;
    private readonly int _featureReportLength;

    private WindowsHidDevice(SafeFileHandle handle, int featureReportLength)
    {
        _handle = handle;
        _featureReportLength = featureReportLength;
    }

    internal static WindowsHidDevice? Find(ushort vendorId, ushort productId)
    {
        NativeMethods.HidD_GetHidGuid(out var hidGuid);
        var deviceInfoSet = NativeMethods.SetupDiGetClassDevs(
            ref hidGuid,
            0,
            0,
            NativeMethods.DigcfPresent | NativeMethods.DigcfDeviceInterface);

        if (deviceInfoSet == -1)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not enumerate HID devices.");
        }

        try
        {
            for (uint index = 0; ; index++)
            {
                var interfaceData = new NativeMethods.SpDeviceInterfaceData
                {
                    Size = (uint)Marshal.SizeOf<NativeMethods.SpDeviceInterfaceData>(),
                };

                if (!NativeMethods.SetupDiEnumDeviceInterfaces(
                        deviceInfoSet,
                        0,
                        ref hidGuid,
                        index,
                        ref interfaceData))
                {
                    const int noMoreItems = 259;
                    var error = Marshal.GetLastWin32Error();
                    if (error == noMoreItems)
                    {
                        return null;
                    }

                    throw new Win32Exception(error, "Could not enumerate a HID device interface.");
                }

                var path = GetDevicePath(deviceInfoSet, ref interfaceData);
                var device = TryOpen(path, vendorId, productId);
                if (device is not null)
                {
                    return device;
                }
            }
        }
        finally
        {
            NativeMethods.SetupDiDestroyDeviceInfoList(deviceInfoSet);
        }
    }

    internal void SetFeature(ReadOnlySpan<byte> report)
    {
        if (report.Length != RazerReport.Size)
        {
            throw new ArgumentException($"Expected a {RazerReport.Size}-byte report.", nameof(report));
        }

        var buffer = new byte[_featureReportLength];
        report.CopyTo(buffer.AsSpan(1));
        if (!NativeMethods.HidD_SetFeature(_handle, buffer, buffer.Length))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "The mouse rejected the HID feature report.");
        }
    }

    internal byte[] GetFeature()
    {
        var buffer = new byte[_featureReportLength];
        if (!NativeMethods.HidD_GetFeature(_handle, buffer, buffer.Length))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read a HID feature report.");
        }

        return buffer.AsSpan(1, RazerReport.Size).ToArray();
    }

    public void Dispose()
    {
        _handle.Dispose();
    }

    private static string GetDevicePath(
        nint deviceInfoSet,
        ref NativeMethods.SpDeviceInterfaceData interfaceData)
    {
        NativeMethods.SetupDiGetDeviceInterfaceDetail(
            deviceInfoSet,
            ref interfaceData,
            0,
            0,
            out var requiredSize,
            0);

        var buffer = Marshal.AllocHGlobal((int)requiredSize);
        try
        {
            Marshal.WriteInt32(buffer, nint.Size == 8 ? 8 : 6);
            if (!NativeMethods.SetupDiGetDeviceInterfaceDetail(
                    deviceInfoSet,
                    ref interfaceData,
                    buffer,
                    requiredSize,
                    out _,
                    0))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read a HID device path.");
            }

            return Marshal.PtrToStringUni(buffer + sizeof(uint))
                ?? throw new InvalidOperationException("The HID device path was empty.");
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static WindowsHidDevice? TryOpen(string path, ushort vendorId, ushort productId)
    {
        if (!path.Contains("&MI_00#", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var handle = NativeMethods.CreateFile(
            path,
            NativeMethods.GenericRead | NativeMethods.GenericWrite,
            NativeMethods.FileShareRead | NativeMethods.FileShareWrite,
            0,
            NativeMethods.OpenExisting,
            0,
            0);

        if (handle.IsInvalid)
        {
            handle.Dispose();
            handle = NativeMethods.CreateFile(
                path,
                0,
                NativeMethods.FileShareRead | NativeMethods.FileShareWrite,
                0,
                NativeMethods.OpenExisting,
                0,
                0);
            if (handle.IsInvalid)
            {
                handle.Dispose();
                return null;
            }
        }

        var ownsHandle = true;
        try
        {
            var attributes = new NativeMethods.HiddAttributes
            {
                Size = Marshal.SizeOf<NativeMethods.HiddAttributes>(),
            };

            if (!NativeMethods.HidD_GetAttributes(handle, ref attributes)
                || attributes.VendorId != vendorId
                || attributes.ProductId != productId)
            {
                return null;
            }

            if (!NativeMethods.HidD_GetPreparsedData(handle, out var preparsedData))
            {
                return null;
            }

            try
            {
                var status = NativeMethods.HidP_GetCaps(preparsedData, out var capabilities);
                if (status != NativeMethods.HidpStatusSuccess
                    || capabilities.UsagePage != 0x01
                    || capabilities.Usage != 0x02
                    || capabilities.FeatureReportByteLength < RazerReport.Size + 1)
                {
                    return null;
                }

                ownsHandle = false;
                return new WindowsHidDevice(handle, capabilities.FeatureReportByteLength);
            }
            finally
            {
                NativeMethods.HidD_FreePreparsedData(preparsedData);
            }
        }
        finally
        {
            if (ownsHandle)
            {
                handle.Dispose();
            }
        }
    }
}
