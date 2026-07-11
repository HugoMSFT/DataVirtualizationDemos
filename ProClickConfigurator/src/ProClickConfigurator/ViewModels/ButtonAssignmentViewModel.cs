using ProClickConfigurator.Core.Models;

namespace ProClickConfigurator.ViewModels;

public sealed class ButtonAssignmentViewModel : ObservableObject
{
    private readonly Action _changed;
    private WindowsActionDefinition _primaryAction;
    private WindowsActionDefinition _hyperShiftAction;

    public ButtonAssignmentViewModel(
        MouseButtonId button,
        WindowsActionDefinition primaryAction,
        WindowsActionDefinition hyperShiftAction,
        Action changed)
    {
        Button = button;
        _primaryAction = primaryAction;
        _hyperShiftAction = hyperShiftAction;
        _changed = changed;
    }

    public MouseButtonId Button { get; }

    public string DisplayName => Button switch
    {
        MouseButtonId.Left => "Left click",
        MouseButtonId.Right => "Right click",
        MouseButtonId.Middle => "Wheel click",
        MouseButtonId.Back => "Side back",
        MouseButtonId.Forward => "Side forward",
        MouseButtonId.TiltLeft => "Wheel tilt left",
        MouseButtonId.TiltRight => "Wheel tilt right",
        _ => Button.ToString(),
    };

    public bool CanBeHyperShiftModifier =>
        Button is not (MouseButtonId.TiltLeft or MouseButtonId.TiltRight);

    public bool CanAssignHyperShiftAction =>
        PrimaryAction.Kind != WindowsActionKind.HyperShift;

    public WindowsActionDefinition PrimaryAction
    {
        get => _primaryAction;
        set
        {
            var normalized = !CanBeHyperShiftModifier && value.Kind == WindowsActionKind.HyperShift
                ? WindowsActionCatalog.Get(WindowsActionCatalog.PassthroughId)
                : value;
            if (SetProperty(ref _primaryAction, normalized))
            {
                if (!CanAssignHyperShiftAction)
                {
                    _hyperShiftAction = WindowsActionCatalog.Get(WindowsActionCatalog.PassthroughId);
                    OnPropertyChanged(nameof(HyperShiftAction));
                }

                OnPropertyChanged(nameof(CanAssignHyperShiftAction));
                _changed();
            }
        }
    }

    public WindowsActionDefinition HyperShiftAction
    {
        get => _hyperShiftAction;
        set
        {
            var normalized = CanAssignHyperShiftAction
                ? value
                : WindowsActionCatalog.Get(WindowsActionCatalog.PassthroughId);
            if (SetProperty(ref _hyperShiftAction, normalized))
            {
                _changed();
            }
        }
    }
}
