namespace ProClickConfigurator.Core.Device;

internal interface IRazerHidDevice : IDisposable
{
    void SetFeature(ReadOnlySpan<byte> report);

    byte[] GetFeature();
}
