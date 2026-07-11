namespace ProClickConfigurator.Core.Models;

public sealed record DpiStage(int X, int Y)
{
    public DpiStage(int value)
        : this(value, value)
    {
    }
}
