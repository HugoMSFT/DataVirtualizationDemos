using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using ProClickConfigurator.Core.Models;
using ShapePath = Avalonia.Controls.Shapes.Path;

namespace ProClickConfigurator.Mac.Controls;

public partial class MouseDiagram : UserControl
{
    public static readonly StyledProperty<MouseButtonId> SelectedButtonProperty =
        AvaloniaProperty.Register<MouseDiagram, MouseButtonId>(
            nameof(SelectedButton),
            MouseButtonId.Back);

    private readonly Dictionary<MouseButtonId, ShapePath> _parts;
    private readonly Dictionary<MouseButtonId, IBrush?> _defaultFills;

    static MouseDiagram()
    {
        SelectedButtonProperty.Changed.AddClassHandler<MouseDiagram>(
            (control, _) => control.UpdateSelection());
    }

    public MouseDiagram()
    {
        InitializeComponent();
        _parts = new Dictionary<MouseButtonId, ShapePath>
        {
            [MouseButtonId.Left] = this.FindControl<ShapePath>("LeftPart")!,
            [MouseButtonId.Right] = this.FindControl<ShapePath>("RightPart")!,
            [MouseButtonId.Middle] = this.FindControl<ShapePath>("MiddlePart")!,
            [MouseButtonId.Back] = this.FindControl<ShapePath>("BackPart")!,
            [MouseButtonId.Forward] = this.FindControl<ShapePath>("ForwardPart")!,
            [MouseButtonId.TiltLeft] = this.FindControl<ShapePath>("TiltLeftPart")!,
            [MouseButtonId.TiltRight] = this.FindControl<ShapePath>("TiltRightPart")!,
        };
        _defaultFills = _parts.ToDictionary(pair => pair.Key, pair => pair.Value.Fill);
        UpdateSelection();
    }

    public event EventHandler<MouseButtonSelectedEventArgs>? ButtonSelected;

    public MouseButtonId SelectedButton
    {
        get => GetValue(SelectedButtonProperty);
        set => SetValue(SelectedButtonProperty, value);
    }

    private void OnPartPressed(object? sender, PointerPressedEventArgs args)
    {
        if (sender is not ShapePath { Tag: MouseButtonId button })
        {
            return;
        }

        SelectedButton = button;
        ButtonSelected?.Invoke(this, new MouseButtonSelectedEventArgs(button));
        args.Handled = true;
    }

    private void UpdateSelection()
    {
        if (_parts is null)
        {
            return;
        }

        var selectedFill = (IBrush)Resources["SelectedSurfaceBrush"]!;
        var selectedStroke = (IBrush)Resources["SelectedStrokeBrush"]!;
        var defaultStroke = (IBrush)Resources["MouseStrokeBrush"]!;
        foreach (var (button, part) in _parts)
        {
            var isSelected = button == SelectedButton;
            part.Fill = isSelected ? selectedFill : _defaultFills[button];
            part.Stroke = isSelected ? selectedStroke : defaultStroke;
            part.StrokeThickness = isSelected ? 3 : 1.5;
        }
    }
}

public sealed class MouseButtonSelectedEventArgs(MouseButtonId button) : EventArgs
{
    public MouseButtonId Button { get; } = button;
}
