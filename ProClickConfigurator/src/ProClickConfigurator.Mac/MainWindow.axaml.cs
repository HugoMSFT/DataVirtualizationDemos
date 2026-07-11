using Avalonia.Controls;
using Avalonia.Threading;
using ProClickConfigurator.Core.Profiles;
using ProClickConfigurator.Core.ViewModels;
using ProClickConfigurator.Mac.Controls;

namespace ProClickConfigurator.Mac;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private readonly DispatcherTimer _batteryTimer;

    public MainWindow()
    {
        InitializeComponent();
        _viewModel = new MainViewModel(JsonProfileStore.CreateDefault());
        DataContext = _viewModel;

        _batteryTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMinutes(1),
        };
        _batteryTimer.Tick += OnBatteryTimerTick;
        Opened += OnOpened;
        Closed += OnClosed;
    }

    private async void OnOpened(object? sender, EventArgs args)
    {
        await _viewModel.InitializeAsync();
        _batteryTimer.Start();
    }

    private async void OnBatteryTimerTick(object? sender, EventArgs args)
    {
        await _viewModel.RefreshBatteryAsync();
    }

    private void OnMouseButtonSelected(object? sender, MouseButtonSelectedEventArgs args)
    {
        _viewModel.SelectButtonCommand.Execute(args.Button);
    }

    private void OnRemoveDpiStage(object? sender, Avalonia.Interactivity.RoutedEventArgs args)
    {
        if (sender is Button { Tag: DpiStageViewModel stage })
        {
            _viewModel.RemoveDpiStageCommand.Execute(stage);
        }
    }

    private void OnClosed(object? sender, EventArgs args)
    {
        _batteryTimer.Stop();
        _batteryTimer.Tick -= OnBatteryTimerTick;
        _viewModel.Dispose();
    }
}