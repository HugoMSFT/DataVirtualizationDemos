namespace ProClickConfigurator.Core.Protocol;

public sealed class RazerReport
{
    public const int Size = 90;
    public const int MaximumArgumentCount = 80;

    private const int ArgumentOffset = 8;
    private const int CrcOffset = 88;
    private readonly byte[] _bytes;

    private RazerReport(byte[] bytes)
    {
        _bytes = bytes;
    }

    public RazerCommandStatus Status => (RazerCommandStatus)_bytes[0];

    public byte TransactionId => _bytes[1];

    public byte DataSize => _bytes[5];

    public byte CommandClass => _bytes[6];

    public byte CommandId => _bytes[7];

    public ReadOnlySpan<byte> Arguments => _bytes.AsSpan(ArgumentOffset, DataSize);

    public static RazerReport Create(
        byte transactionId,
        byte commandClass,
        byte commandId,
        byte dataSize,
        ReadOnlySpan<byte> arguments = default)
    {
        if (dataSize > MaximumArgumentCount)
        {
            throw new ArgumentOutOfRangeException(nameof(dataSize));
        }

        if (arguments.Length > dataSize)
        {
            throw new ArgumentException("Arguments cannot exceed the declared data size.", nameof(arguments));
        }

        var bytes = new byte[Size];
        bytes[1] = transactionId;
        bytes[5] = dataSize;
        bytes[6] = commandClass;
        bytes[7] = commandId;
        arguments.CopyTo(bytes.AsSpan(ArgumentOffset));
        bytes[CrcOffset] = CalculateCrc(bytes);
        return new RazerReport(bytes);
    }

    public static RazerReport Parse(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length != Size)
        {
            throw new RazerProtocolException($"Expected a {Size}-byte report, received {bytes.Length} bytes.");
        }

        if (bytes[5] > MaximumArgumentCount)
        {
            throw new RazerProtocolException($"Device reported an invalid payload size of {bytes[5]} bytes.");
        }

        var expectedCrc = CalculateCrc(bytes);
        if (bytes[CrcOffset] != expectedCrc)
        {
            throw new RazerProtocolException(
                $"Report checksum mismatch: expected 0x{expectedCrc:X2}, received 0x{bytes[CrcOffset]:X2}.");
        }

        return new RazerReport(bytes.ToArray());
    }

    public byte[] ToArray()
    {
        var copy = (byte[])_bytes.Clone();
        copy[CrcOffset] = CalculateCrc(copy);
        return copy;
    }

    public static byte CalculateCrc(ReadOnlySpan<byte> report)
    {
        if (report.Length < CrcOffset)
        {
            throw new ArgumentException($"A Razer report must contain at least {CrcOffset} bytes.", nameof(report));
        }

        byte crc = 0;
        for (var index = 2; index < CrcOffset; index++)
        {
            crc ^= report[index];
        }

        return crc;
    }
}
