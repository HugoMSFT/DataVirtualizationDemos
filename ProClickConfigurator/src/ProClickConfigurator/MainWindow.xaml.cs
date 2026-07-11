using ProClickConfigurator.Controls;
using ProClickConfigurator.Core.Profiles;
using ProClickConfigurator.ViewModels;
using System.Windows;
using System.Windows.Threading;

namespace ProClickConfigurator;

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
        Loaded += OnLoaded;
        Closed += OnClosed;
    }

    private async void OnLoaded(object sender, RoutedEventArgs args)
    {
        await _viewModel.InitializeAsync();
        _batteryTimer.Start();
    }

    private async void OnBatteryTimerTick(object? sender, EventArgs args)
    {
        await _viewModel.RefreshBatteryAsync();
    }

    private void OnMouseButtonSelected(object sender, MouseButtonSelectedEventArgs args)
    {
        _viewModel.SelectButtonCommand.Execute(args.Button);
    }

    private void OnClosed(object? sender, EventArgs args)
    {
        _batteryTimer.Stop();
        _batteryTimer.Tick -= OnBatteryTimerTick;
        _viewModel.Dispose();
    }
}
