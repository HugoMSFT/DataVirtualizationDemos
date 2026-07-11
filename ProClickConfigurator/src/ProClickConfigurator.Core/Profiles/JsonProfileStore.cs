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

    public JsonProfileStore(string filePath)
    {
        _filePath = filePath;
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

        await using var stream = File.OpenRead(_filePath);
        var profile = await JsonSerializer.DeserializeAsync<MouseProfile>(
            stream,
            SerializerOptions,
            cancellationToken);
        if (profile is null)
        {
            throw new InvalidDataException($"Profile '{_filePath}' did not contain a JSON object.");
        }

        profile.Normalize();
        return profile;
    }

    public async Task SaveAsync(MouseProfile profile, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(profile);
        profile.Normalize();

        var directory = Path.GetDirectoryName(_filePath)
            ?? throw new InvalidOperationException("The profile path has no parent directory.");
        Directory.CreateDirectory(directory);

        var temporaryPath = _filePath + ".tmp";
        await using (var stream = File.Create(temporaryPath))
        {
            await JsonSerializer.SerializeAsync(
                stream,
                profile,
                SerializerOptions,
                cancellationToken);
        }

        File.Move(temporaryPath, _filePath, overwrite: true);
    }
}
