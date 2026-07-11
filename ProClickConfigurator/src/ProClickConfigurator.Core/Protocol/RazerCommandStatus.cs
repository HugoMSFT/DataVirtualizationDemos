namespace ProClickConfigurator.Core.Protocol;

public enum RazerCommandStatus : byte
{
    New = 0x00,
    Busy = 0x01,
    Successful = 0x02,
    Failure = 0x03,
    Timeout = 0x04,
    NotSupported = 0x05,
}
