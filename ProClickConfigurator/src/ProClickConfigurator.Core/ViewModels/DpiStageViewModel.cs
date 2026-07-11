namespace ProClickConfigurator.Core.ViewModels;

public sealed class DpiStageViewModel : ObservableObject
{
    private readonly Action _changed;
    private int _number;
    private int _value;

    public DpiStageViewModel(int number, int value, Action changed)
    {
        _number = number;
        _value = value;
        _changed = changed;
    }

    public int Number
    {
        get => _number;
        internal set => SetProperty(ref _number, value);
    }

    public int Value
    {
        get => _value;
        set
        {
            var normalized = Math.Clamp(
                (int)Math.Round(value / 100d, MidpointRounding.AwayFromZero) * 100,
                100,
                12000);
            if (SetProperty(ref _value, normalized))
            {
                _changed();
            }
        }
    }
}
