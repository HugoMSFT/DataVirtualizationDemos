namespace ProClickConfigurator.Core.Protocol;

public sealed class RazerProtocolException : IOException
{
    public RazerProtocolException(string message)
        : base(message)
    {
    }

    public RazerProtocolException(string message, RazerCommandStatus status)
        : base(message)
    {
        Status = status;
    }

    public RazerProtocolException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public RazerCommandStatus? Status { get; }
}
