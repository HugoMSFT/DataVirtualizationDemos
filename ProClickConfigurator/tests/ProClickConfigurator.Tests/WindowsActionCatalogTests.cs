using ProClickConfigurator.Core.Models;

namespace ProClickConfigurator.Tests;

public sealed class WindowsActionCatalogTests
{
    [Fact]
    public void ActionIdentifiersAreUnique()
    {
        var duplicates = WindowsActionCatalog.All
            .GroupBy(action => action.Id, StringComparer.Ordinal)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToArray();

        Assert.Empty(duplicates);
    }

    [Fact]
    public void CatalogContainsCoreMouseWindowsEditingAndMediaActions()
    {
        Assert.Contains(WindowsActionCatalog.All, action => action.Kind == WindowsActionKind.HyperShift);
        Assert.Contains(WindowsActionCatalog.All, action => action.Id == "mouse.left");
        Assert.Contains(WindowsActionCatalog.All, action => action.Id == "edit.copy");
        Assert.Contains(WindowsActionCatalog.All, action => action.Id == "windows.task-view");
        Assert.Contains(WindowsActionCatalog.All, action => action.Id == "media.play-pause");
    }
}
