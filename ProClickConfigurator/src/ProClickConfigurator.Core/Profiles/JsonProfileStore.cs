using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ProClickConfigurator.Core.Profiles;

public sealed class JsonProfileStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    private readonly string _filePath;
    private readonly string _presetDirectory;

    public JsonProfileStore(string filePath, string? presetDirectory = null)
    {
        _filePath = filePath;
        _presetDirectory = presetDirectory
            ?? Path.Combine(
                Path.GetDirectoryName(filePath)
                    ?? throw new ArgumentException("The profile path has no parent directory.", nameof(filePath)),
                "Presets");
    }

    public static JsonProfileStore CreateDefault()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ProClickConfigurator");
        return new JsonProfileStore(Path.Combine(directory, "profile.json"));
    }

    public async Task<MouseProfile> LoadAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_filePath))
        {
            return MouseProfile.CreateDefault();
        }

        return await LoadFileAsync(_filePath, cancellationToken);
    }

    public async Task SaveAsync(MouseProfile profile, CancellationToken cancellationToken = default)
    {
        await SaveFileAsync(_filePath, profile, cancellationToken);
    }

    public async Task<PresetCatalog> ReadPresetCatalogAsync(
        CancellationToken cancellationToken = default)
    {
        if (!Directory.Exists(_presetDirectory))
        {
            return new PresetCatalog([], 0);
        }

        var names = new List<string>();
        var unreadableCount = 0;
        foreach (var path in Directory.EnumerateFiles(_presetDirectory, "*.json"))
        {
            try
            {
                var profile = await LoadFileAsync(path, cancellationToken);
                names.Add(profile.Name);
            }
            catch (Exception exception) when (
                exception is IOException
                    or UnauthorizedAccessException
                    or JsonException
                    or InvalidDataException)
            {
                unreadableCount++;
            }
        }

        return new PresetCatalog(
            names
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray(),
            unreadableCount);
    }

    public sealed record PresetCatalog(
        IReadOnlyList<string> Names,
        int UnreadableCount);

    public Task<MouseProfile> LoadPresetAsync(
        string name,
        CancellationToken cancellationToken = default)
    {
        return LoadFileAsync(GetPresetPath(name), cancellationToken);
    }

    public Task SavePresetAsync(
        MouseProfile profile,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(profile);
        return SaveFileAsync(GetPresetPath(profile.Name), profile, cancellationToken);
    }

    private static async Task<MouseProfile> LoadFileAsync(
        string path,
        CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var profile = await JsonSerializer.DeserializeAsync<MouseProfile>(
            stream,
            SerializerOptions,
            cancellationToken);
        if (profile is null)
        {
            throw new InvalidDataException($"Profile '{path}' did not contain a JSON object.");
        }

        profile.Normalize();
        return profile;
    }

    private static async Task SaveFileAsync(
        string path,
        MouseProfile profile,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(profile);
        var normalized = profile.Clone();
        normalized.Normalize();

        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("The profile path has no parent directory.");
        Directory.CreateDirectory(directory);

        var temporaryPath = path + ".tmp";
        await using (var stream = File.Create(temporaryPath))
        {
            await JsonSerializer.SerializeAsync(
                stream,
                normalized,
                SerializerOptions,
                cancellationToken);
        }

        File.Move(temporaryPath, path, overwrite: true);
    }

    private string GetPresetPath(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Preset name cannot be empty.", nameof(name));
        }

        var normalizedName = name.Trim().ToUpperInvariant();
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalizedName)));
        return Path.Combine(_presetDirectory, $"{hash}.json");
    }
}
