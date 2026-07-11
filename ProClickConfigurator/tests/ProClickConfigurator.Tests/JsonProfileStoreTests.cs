using ProClickConfigurator.Core.Models;
using ProClickConfigurator.Core.Profiles;

namespace ProClickConfigurator.Tests;

public sealed class JsonProfileStoreTests
{
    [Fact]
    public async Task SaveAndLoadRoundTripsAssignmentsAndSettings()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pro-click-tests-{Guid.NewGuid():N}");
        var path = Path.Combine(directory, "profile.json");

        try
        {
            var store = new JsonProfileStore(path);
            var profile = MouseProfile.CreateDefault();
            profile.Name = "Editing";
            profile.CurrentDpi = 1600;
            profile.DpiStages = [800, 1600, 3200];
            profile.ActiveDpiStage = 2;
            profile.PollingRateHz = 500;
            profile.PrimaryAssignments[MouseButtonId.Back] = WindowsActionCatalog.HyperShiftId;
            profile.HyperShiftAssignments[MouseButtonId.Forward] = "edit.copy";

            await store.SaveAsync(profile);
            var loaded = await store.LoadAsync();

            Assert.Equal("Editing", loaded.Name);
            Assert.Equal(1600, loaded.CurrentDpi);
            Assert.Equal([800, 1600, 3200], loaded.DpiStages);
            Assert.Equal(2, loaded.ActiveDpiStage);
            Assert.Equal(500, loaded.PollingRateHz);
            Assert.Equal(WindowsActionCatalog.HyperShiftId, loaded.PrimaryAssignments[MouseButtonId.Back]);
            Assert.Equal("edit.copy", loaded.HyperShiftAssignments[MouseButtonId.Forward]);
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }

    [Fact]
    public async Task LoadReturnsDefaultsOnlyWhenProfileDoesNotExist()
    {
        var path = Path.Combine(
            Path.GetTempPath(),
            $"missing-pro-click-profile-{Guid.NewGuid():N}",
            "profile.json");
        var store = new JsonProfileStore(path);

        var profile = await store.LoadAsync();

        Assert.Equal("Default", profile.Name);
        Assert.All(
            Enum.GetValues<MouseButtonId>(),
            button => Assert.Equal(
                WindowsActionCatalog.PassthroughId,
                profile.PrimaryAssignments[button]));
    }

    [Fact]
    public async Task NamedPresetsCanBeListedAndLoaded()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pro-click-presets-{Guid.NewGuid():N}");
        var store = new JsonProfileStore(
            Path.Combine(directory, "profile.json"),
            Path.Combine(directory, "presets"));

        try
        {
            var editing = MouseProfile.CreateDefault();
            editing.Name = "Editing";
            editing.CurrentDpi = 1200;
            var travel = MouseProfile.CreateDefault();
            travel.Name = "Travel";
            travel.CurrentDpi = 800;

            await store.SavePresetAsync(travel);
            await store.SavePresetAsync(editing);

            var catalog = await store.ReadPresetCatalogAsync();
            Assert.Equal(["Editing", "Travel"], catalog.Names);
            Assert.Equal(0, catalog.UnreadableCount);
            Assert.Equal(1200, (await store.LoadPresetAsync("editing")).CurrentDpi);
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }

    [Fact]
    public async Task PresetCatalogReportsAndSkipsUnreadableFiles()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pro-click-presets-{Guid.NewGuid():N}");
        var presetDirectory = Path.Combine(directory, "presets");
        var store = new JsonProfileStore(
            Path.Combine(directory, "profile.json"),
            presetDirectory);

        try
        {
            var valid = MouseProfile.CreateDefault();
            valid.Name = "Travel";
            await store.SavePresetAsync(valid);
            await File.WriteAllTextAsync(
                Path.Combine(presetDirectory, "invalid.json"),
                """{"schemaVersion":999}""");

            var catalog = await store.ReadPresetCatalogAsync();

            Assert.Equal(["Travel"], catalog.Names);
            Assert.Equal(1, catalog.UnreadableCount);
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }
}
