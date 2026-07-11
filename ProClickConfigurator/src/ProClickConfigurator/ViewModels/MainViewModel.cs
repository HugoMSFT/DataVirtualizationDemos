using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.Profiles;
using ProClickConfigurator.Core.Protocol;
using ProClickConfigurator.Device;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Text.Json;

namespace ProClickConfigurator.ViewModels;

public sealed class MainViewModel : ObservableObject, IDisposable
{
    private readonly JsonProfileStore _profileStore;
    private readonly SemaphoreSlim _deviceOperationLock = new(1, 1);
    private readonly IReadOnlyList<WindowsActionDefinition> _allPrimaryActions;
    private MouseProfile _profile = MouseProfile.CreateDefault();
    private ProClickMiniDevice? _device;
    private ButtonAssignmentViewModel? _selectedAssignment;
    private bool _isBusy;
    private bool _isConnected;
    private bool _canWriteOnboardAssignments;
    private bool _updatingView;
    private string _connectionStatus = "Looking for receiver";
    private string _statusMessage = "Ready";
    private string _profileName = "Default";
    private int _currentDpi = 800;
    private int _activeDpiStage = 1;
    private int _pollingRateHz = 1000;
    private int _batteryPercent;
    private int _idleTimeSeconds = 300;
    private int _lowBatteryThresholdPercent = 5;
    private string _firmwareVersion = "--";

    public MainViewModel(JsonProfileStore profileStore)
    {
        _profileStore = profileStore;

        _allPrimaryActions = WindowsActionCatalog.All;

        RefreshDeviceCommand = new AsyncRelayCommand(RefreshFromMouseAsync, () => !IsBusy);
        ApplyToMouseCommand = new AsyncRelayCommand(ApplyToMouseAsync, () => IsConnected && !IsBusy);
        SaveProfileCommand = new AsyncRelayCommand(SaveProfileAsync, () => !IsBusy);
        ReloadProfileCommand = new AsyncRelayCommand(ReloadProfileAsync, () => !IsBusy);
        AddDpiStageCommand = new RelayCommand(
            _ => AddDpiStage(),
            _ => DpiStages.Count < ProClickMiniDevice.MaximumDpiStages);
        RemoveDpiStageCommand = new RelayCommand(
            stage => RemoveDpiStage(stage as DpiStageViewModel),
            _ => DpiStages.Count > 1);
        SelectButtonCommand = new RelayCommand(
            button =>
            {
                if (button is MouseButtonId buttonId)
                {
                    SelectedAssignment = ButtonAssignments.First(item => item.Button == buttonId);
                }
            });

        ApplyProfileToView(_profile);
    }

    public ObservableCollection<DpiStageViewModel> DpiStages { get; } = [];

    public ObservableCollection<int> ActiveDpiStageChoices { get; } = [];

    public ObservableCollection<ButtonAssignmentViewModel> ButtonAssignments { get; } = [];

    public IReadOnlyList<int> PollingRates { get; } = [125, 500, 1000];

    public IReadOnlyList<int> IdleTimeOptions { get; } = [60, 120, 180, 300, 600, 900];

    public IReadOnlyList<WindowsActionDefinition> HyperShiftActions =>
        FilterActions(allowHyperShiftModifier: false);

    public IReadOnlyList<WindowsActionDefinition> AvailablePrimaryActions =>
        FilterActions(SelectedAssignment?.CanBeHyperShiftModifier != false);

    public AsyncRelayCommand RefreshDeviceCommand { get; }

    public AsyncRelayCommand ApplyToMouseCommand { get; }

    public AsyncRelayCommand SaveProfileCommand { get; }

    public AsyncRelayCommand ReloadProfileCommand { get; }

    public RelayCommand AddDpiStageCommand { get; }

    public RelayCommand RemoveDpiStageCommand { get; }

    public RelayCommand SelectButtonCommand { get; }

    public ButtonAssignmentViewModel? SelectedAssignment
    {
        get => _selectedAssignment;
        set
        {
            if (SetProperty(ref _selectedAssignment, value))
            {
                OnPropertyChanged(nameof(AvailablePrimaryActions));
                OnPropertyChanged(nameof(HyperShiftActions));
                OnPropertyChanged(nameof(SelectedButton));
            }
        }
    }

    public MouseButtonId SelectedButton =>
        SelectedAssignment?.Button ?? MouseButtonId.Back;

    public string ProfileName
    {
        get => _profileName;
        set
        {
            if (SetProperty(ref _profileName, value))
            {
                SyncProfileFromView();
            }
        }
    }

    public int CurrentDpi
    {
        get => _currentDpi;
        set
        {
            var normalized = Math.Clamp(
                (int)Math.Round(value / 100d, MidpointRounding.AwayFromZero) * 100,
                ProClickMiniDevice.MinimumDpi,
                ProClickMiniDevice.MaximumDpi);
            if (SetProperty(ref _currentDpi, normalized))
            {
                SyncProfileFromView();
            }
        }
    }

    public int ActiveDpiStage
    {
        get => _activeDpiStage;
        set
        {
            var normalized = Math.Clamp(value, 1, Math.Max(1, DpiStages.Count));
            if (SetProperty(ref _activeDpiStage, normalized))
            {
                SyncProfileFromView();
            }
        }
    }

    public int PollingRateHz
    {
        get => _pollingRateHz;
        set
        {
            if (SetProperty(ref _pollingRateHz, value))
            {
                SyncProfileFromView();
            }
        }
    }

    public int BatteryPercent
    {
        get => _batteryPercent;
        private set
        {
            if (SetProperty(ref _batteryPercent, value))
            {
                OnPropertyChanged(nameof(BatteryLabel));
            }
        }
    }

    public string BatteryLabel => IsConnected ? $"{BatteryPercent}%" : "--";

    public int IdleTimeSeconds
    {
        get => _idleTimeSeconds;
        set
        {
            if (SetProperty(ref _idleTimeSeconds, value))
            {
                SyncProfileFromView();
            }
        }
    }

    public int LowBatteryThresholdPercent
    {
        get => _lowBatteryThresholdPercent;
        set
        {
            var normalized = Math.Clamp(value, 5, 25);
            if (SetProperty(ref _lowBatteryThresholdPercent, normalized))
            {
                SyncProfileFromView();
            }
        }
    }

    public string FirmwareVersion
    {
        get => _firmwareVersion;
        private set => SetProperty(ref _firmwareVersion, value);
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            if (SetProperty(ref _isBusy, value))
            {
                RaiseCommandStates();
            }
        }
    }

    public bool IsConnected
    {
        get => _isConnected;
        private set
        {
            if (SetProperty(ref _isConnected, value))
            {
                OnPropertyChanged(nameof(BatteryLabel));
                RaiseCommandStates();
            }
        }
    }

    public string AssignmentStorageLabel => _canWriteOnboardAssignments
        ? "Onboard profile detected"
        : "Onboard assignments unavailable";

    public string ConnectionStatus
    {
        get => _connectionStatus;
        private set => SetProperty(ref _connectionStatus, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        private set => SetProperty(ref _statusMessage, value);
    }

    public async Task InitializeAsync()
    {
        Exception? profileLoadError = null;
        await RunGuardedAsync(
            async () =>
            {
                _profile = await _profileStore.LoadAsync();
                ApplyProfileToView(_profile);
                StatusMessage = "Local profile loaded.";
            },
            exception =>
            {
                profileLoadError = exception;
                SetStatusError(exception);
            });

        await RefreshFromMouseAsync();
        if (profileLoadError is not null)
        {
            StatusMessage = $"Using the default local profile: {profileLoadError.Message}";
        }
    }

    public async Task RefreshBatteryAsync()
    {
        if (_device is null || IsBusy || !IsConnected)
        {
            return;
        }

        if (!await _deviceOperationLock.WaitAsync(0))
        {
            return;
        }

        try
        {
            var device = _device;
            if (device is null)
            {
                return;
            }

            BatteryPercent = await device.ReadBatteryPercentAsync();
        }
        catch (IOException exception)
        {
            if (exception is RazerProtocolException
                {
                    Status: RazerCommandStatus.Timeout,
                })
            {
                SetMouseAsleep();
            }
            else
            {
                Disconnect(exception.Message);
            }
        }
        catch (Win32Exception exception)
        {
            Disconnect(exception.Message);
        }
        finally
        {
            _deviceOperationLock.Release();
        }
    }

    public void Dispose()
    {
        _device?.Dispose();
    }

    private async Task RefreshFromMouseAsync()
    {
        await RunGuardedAsync(
            async () =>
            {
                await _deviceOperationLock.WaitAsync();
                try
                {
                    _device?.Dispose();
                    _device = null;
                    IsConnected = false;
                    ConnectionStatus = "Looking for receiver";
                    _device = await Task.Run(ProClickMiniDevice.TryConnect);
                    if (_device is null)
                    {
                        Disconnect("Connect the 2.4 GHz receiver and wake the mouse.");
                        return;
                    }

                    ConnectionStatus = "Reading mouse";
                    var snapshot = await _device.ReadSnapshotAsync();
                    ApplySnapshotToView(snapshot);
                    IsConnected = true;
                    ConnectionStatus = "Pro Click Mini connected";
                    StatusMessage = snapshot.OnboardButtonProfile is null
                        ? $"Performance settings read. Assignments were not imported: "
                            + snapshot.OnboardButtonReadError
                        : "Performance and both onboard assignment layers read from mouse.";
                }
                finally
                {
                    _deviceOperationLock.Release();
                }
            },
            HandleDeviceReadError);
    }

    private async Task ApplyToMouseAsync()
    {
        if (_device is null)
        {
            Disconnect("The receiver is not connected.");
            return;
        }

        await RunGuardedAsync(
            async () =>
            {
                await _deviceOperationLock.WaitAsync();
                try
                {
                    var device = _device;
                    if (device is null)
                    {
                        Disconnect("The receiver is not connected.");
                        return;
                    }

                    SyncProfileFromView();
                    var settings = new ProClickMiniSettings(
                        _profile.CurrentDpi,
                        _profile.DpiStages.Select(value => new DpiStage(value)).ToArray(),
                        _profile.ActiveDpiStage,
                        _profile.PollingRateHz,
                        _profile.IdleTimeSeconds,
                        _profile.LowBatteryThresholdPercent);
                    var buttonProfile = _canWriteOnboardAssignments
                        ? new OnboardButtonProfile(
                            new Dictionary<MouseButtonId, string>(_profile.PrimaryAssignments),
                            new Dictionary<MouseButtonId, string>(_profile.HyperShiftAssignments))
                        : null;
                    var snapshot = await device.ApplySettingsAsync(settings, buttonProfile);
                    ApplySnapshotToView(snapshot);
                    StatusMessage = buttonProfile is null
                        ? "Performance and power settings saved; onboard assignments were not changed."
                        : "Performance, primary assignments, and HyperShift saved to mouse memory.";
                }
                finally
                {
                    _deviceOperationLock.Release();
                }
            });
    }

    private async Task SaveProfileAsync()
    {
        await RunGuardedAsync(
            async () =>
            {
                SyncProfileFromView();
                await _profileStore.SaveAsync(_profile);
                StatusMessage = "Assignments and settings saved to the local app profile.";
            });
    }

    private async Task ReloadProfileAsync()
    {
        await RunGuardedAsync(
            async () =>
            {
                _profile = await _profileStore.LoadAsync();
                ApplyProfileToView(_profile);
                StatusMessage = "Local app profile reloaded.";
            });
    }

    private async Task RunGuardedAsync(
        Func<Task> operation,
        Action<Exception>? errorHandler = null)
    {
        if (IsBusy)
        {
            return;
        }

        IsBusy = true;
        try
        {
            await operation();
        }
        catch (Exception exception) when (
            exception is IOException
                or Win32Exception
                or UnauthorizedAccessException
                or InvalidOperationException
                or ArgumentException
                or JsonException)
        {
            if (errorHandler is null)
            {
                SetStatusError(exception);
            }
            else
            {
                errorHandler(exception);
            }
        }
        finally
        {
            IsBusy = false;
        }
    }

    private void ApplyProfileToView(MouseProfile profile)
    {
        _updatingView = true;
        try
        {
            ProfileName = profile.Name;
            CurrentDpi = profile.CurrentDpi;
            PollingRateHz = profile.PollingRateHz;
            IdleTimeSeconds = profile.IdleTimeSeconds;
            LowBatteryThresholdPercent = profile.LowBatteryThresholdPercent;
            ReplaceDpiStages(profile.DpiStages);
            ActiveDpiStage = profile.ActiveDpiStage;
            ReplaceAssignments(profile);
        }
        finally
        {
            _updatingView = false;
        }
    }

    private void ApplySnapshotToView(ProClickMiniSnapshot snapshot)
    {
        _updatingView = true;
        try
        {
            CurrentDpi = snapshot.CurrentDpiX;
            PollingRateHz = snapshot.PollingRateHz;
            IdleTimeSeconds = snapshot.IdleTimeSeconds;
            LowBatteryThresholdPercent = snapshot.LowBatteryThresholdPercent;
            BatteryPercent = snapshot.BatteryPercent;
            FirmwareVersion = snapshot.FirmwareVersion.ToString(2);
            ReplaceDpiStages(snapshot.DpiStages.Select(stage => stage.X));
            ActiveDpiStage = snapshot.ActiveDpiStage;
            if (snapshot.OnboardButtonProfile is { } buttonProfile)
            {
                ReplaceAssignments(buttonProfile);
                _canWriteOnboardAssignments = true;
            }
            else
            {
                _canWriteOnboardAssignments = false;
            }

            OnPropertyChanged(nameof(AssignmentStorageLabel));
        }
        finally
        {
            _updatingView = false;
        }

        SyncProfileFromView();
    }

    private void ReplaceDpiStages(IEnumerable<int> values)
    {
        DpiStages.Clear();
        foreach (var value in values.Take(ProClickMiniDevice.MaximumDpiStages))
        {
            DpiStages.Add(new DpiStageViewModel(DpiStages.Count + 1, value, HandleDpiStagesChanged));
        }

        if (DpiStages.Count == 0)
        {
            DpiStages.Add(new DpiStageViewModel(1, CurrentDpi, HandleDpiStagesChanged));
        }

        RebuildActiveStageChoices();
        RaiseStageCommandStates();
    }

    private void ReplaceAssignments(MouseProfile profile)
    {
        ReplaceAssignments(
            new OnboardButtonProfile(
                profile.PrimaryAssignments,
                profile.HyperShiftAssignments));
    }

    private void ReplaceAssignments(OnboardButtonProfile profile)
    {
        var selectedButton = SelectedAssignment?.Button ?? MouseButtonId.Back;
        ButtonAssignments.Clear();
        foreach (var button in Enum.GetValues<MouseButtonId>())
        {
            ButtonAssignments.Add(
                new ButtonAssignmentViewModel(
                    button,
                    WindowsActionCatalog.Get(profile.PrimaryAssignments[button]),
                    WindowsActionCatalog.Get(profile.HyperShiftAssignments[button]),
                    HandleAssignmentsChanged));
        }

        SelectedAssignment = ButtonAssignments.First(item => item.Button == selectedButton);
        OnPropertyChanged(nameof(SelectedButton));
    }

    private void AddDpiStage()
    {
        if (DpiStages.Count >= ProClickMiniDevice.MaximumDpiStages)
        {
            return;
        }

        var value = DpiStages.Count == 0 ? CurrentDpi : DpiStages[^1].Value;
        DpiStages.Add(new DpiStageViewModel(DpiStages.Count + 1, value, HandleDpiStagesChanged));
        RebuildActiveStageChoices();
        RaiseStageCommandStates();
        SyncProfileFromView();
    }

    private void RemoveDpiStage(DpiStageViewModel? stage)
    {
        if (stage is null || DpiStages.Count <= 1)
        {
            return;
        }

        DpiStages.Remove(stage);
        for (var index = 0; index < DpiStages.Count; index++)
        {
            DpiStages[index].Number = index + 1;
        }

        ActiveDpiStage = Math.Min(ActiveDpiStage, DpiStages.Count);
        RebuildActiveStageChoices();
        RaiseStageCommandStates();
        SyncProfileFromView();
    }

    private void RebuildActiveStageChoices()
    {
        ActiveDpiStageChoices.Clear();
        for (var number = 1; number <= DpiStages.Count; number++)
        {
            ActiveDpiStageChoices.Add(number);
        }
    }

    private void HandleDpiStagesChanged()
    {
        SyncProfileFromView();
    }

    private void HandleAssignmentsChanged()
    {
        SyncProfileFromView();
        OnPropertyChanged(nameof(AvailablePrimaryActions));
        StatusMessage = _canWriteOnboardAssignments
            ? "Assignment updated. Select Apply to mouse to store it onboard."
            : "Assignment updated locally; onboard assignment access is unavailable.";
    }

    private void SyncProfileFromView()
    {
        if (_updatingView)
        {
            return;
        }

        _profile.Name = ProfileName;
        _profile.CurrentDpi = CurrentDpi;
        _profile.DpiStages = DpiStages.Select(stage => stage.Value).ToList();
        _profile.ActiveDpiStage = ActiveDpiStage;
        _profile.PollingRateHz = PollingRateHz;
        _profile.IdleTimeSeconds = IdleTimeSeconds;
        _profile.LowBatteryThresholdPercent = LowBatteryThresholdPercent;

        foreach (var assignment in ButtonAssignments)
        {
            _profile.PrimaryAssignments[assignment.Button] = assignment.PrimaryAction.Id;
            _profile.HyperShiftAssignments[assignment.Button] = assignment.HyperShiftAction.Id;
        }

        _profile.Normalize();
    }

    private void RaiseCommandStates()
    {
        RefreshDeviceCommand.RaiseCanExecuteChanged();
        ApplyToMouseCommand.RaiseCanExecuteChanged();
        SaveProfileCommand.RaiseCanExecuteChanged();
        ReloadProfileCommand.RaiseCanExecuteChanged();
    }

    private IReadOnlyList<WindowsActionDefinition> FilterActions(bool allowHyperShiftModifier)
    {
        var selectedButton = SelectedAssignment?.Button;
        return _allPrimaryActions
            .Where(action => allowHyperShiftModifier || action.Kind != WindowsActionKind.HyperShift)
            .Where(action => selectedButton is null || action.MouseButton != selectedButton)
            .ToArray();
    }

    private void RaiseStageCommandStates()
    {
        AddDpiStageCommand.RaiseCanExecuteChanged();
        RemoveDpiStageCommand.RaiseCanExecuteChanged();
    }

    private void HandleDeviceReadError(Exception exception)
    {
        if (exception is RazerProtocolException
            {
                Status: RazerCommandStatus.Timeout,
            })
        {
            SetMouseAsleep();
            return;
        }

        Disconnect(exception.Message);
    }

    private void SetMouseAsleep()
    {
        IsConnected = false;
        ConnectionStatus = "Receiver connected - wake mouse";
        BatteryPercent = 0;
        FirmwareVersion = "--";
        StatusMessage = "Move or click the mouse, then select Read from mouse.";
    }

    private void Disconnect(string reason)
    {
        _device?.Dispose();
        _device = null;
        IsConnected = false;
        ConnectionStatus = "Receiver disconnected";
        BatteryPercent = 0;
        FirmwareVersion = "--";
        StatusMessage = reason;
    }

    private void SetStatusError(Exception exception)
    {
        StatusMessage = $"Error: {exception.Message}";
    }
}
