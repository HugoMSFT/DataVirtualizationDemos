using ProClickConfigurator.Core.Models;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;

namespace ProClickConfigurator.Controls;

public partial class MouseDiagram : UserControl
{
    public static readonly DependencyProperty SelectedButtonProperty = DependencyProperty.Register(
        nameof(SelectedButton),
        typeof(MouseButtonId),
        typeof(MouseDiagram),
        new PropertyMetadata(MouseButtonId.Back, OnSelectedButtonChanged));

    private readonly Dictionary<MouseButtonId, Path> _parts;
    private readonly Dictionary<MouseButtonId, Brush> _defaultFills;

    public MouseDiagram()
    {
        InitializeComponent();
        _parts = new Dictionary<MouseButtonId, Path>
        {
            [MouseButtonId.Left] = LeftPart,
            [MouseButtonId.Right] = RightPart,
            [MouseButtonId.Middle] = MiddlePart,
            [MouseButtonId.Back] = BackPart,
            [MouseButtonId.Forward] = ForwardPart,
            [MouseButtonId.TiltLeft] = TiltLeftPart,
            [MouseButtonId.TiltRight] = TiltRightPart,
        };
        _defaultFills = _parts.ToDictionary(pair => pair.Key, pair => pair.Value.Fill);
        UpdateSelection();
    }

    public event EventHandler<MouseButtonSelectedEventArgs>? ButtonSelected;

    public MouseButtonId SelectedButton
    {
        get => (MouseButtonId)GetValue(SelectedButtonProperty);
        set => SetValue(SelectedButtonProperty, value);
    }

    private static void OnSelectedButtonChanged(
        DependencyObject dependencyObject,
        DependencyPropertyChangedEventArgs args)
    {
        ((MouseDiagram)dependencyObject).UpdateSelection();
    }

    private void OnPartClicked(object sender, MouseButtonEventArgs args)
    {
        if (sender is not Path { Tag: MouseButtonId button })
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

        foreach (var (button, part) in _parts)
        {
            var isSelected = button == SelectedButton;
            part.Fill = isSelected
                ? (Brush)FindResource("SelectedSurfaceBrush")
                : _defaultFills[button];
            part.Stroke = isSelected
                ? (Brush)FindResource("SelectedStrokeBrush")
                : (Brush)FindResource("MouseStrokeBrush");
            part.StrokeThickness = isSelected ? 3 : 1.5;
        }
    }
}

public sealed class MouseButtonSelectedEventArgs : EventArgs
{
    public MouseButtonSelectedEventArgs(MouseButtonId button)
    {
        Button = button;
    }

    public MouseButtonId Button { get; }
}
