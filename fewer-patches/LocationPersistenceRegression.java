import com.ryderbelserion.crazycrates.common.CrazyCratesPlugin;
import com.ryderbelserion.crazycrates.common.enums.CrateStatus;
import com.ryderbelserion.crazycrates.common.objects.CrazyLocation;
import com.ryderbelserion.crazycrates.common.storage.impl.file.types.YamlFactory;
import com.ryderbelserion.fusion.core.api.FusionProvider;
import com.ryderbelserion.fusion.files.FileManager;
import com.ryderbelserion.fusion.files.types.configurate.YamlCustomFile;
import com.ryderbelserion.fusion.kyori.FusionKyori;
import org.spongepowered.configurate.CommentedConfigurationNode;
import org.spongepowered.configurate.yaml.YamlConfigurationLoader;
import org.mockito.Mockito;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/** Runs the actual YAML storage methods against a temporary on-disk locations file. */
public class LocationPersistenceRegression {
    public static void main(String[] args) throws Exception {
        Path directory = java.nio.file.Files.createTempDirectory("crazycrates-locations-");
        Path locationFile = directory.resolve("locations.yml");
        YamlConfigurationLoader loader = YamlConfigurationLoader.builder().path(locationFile).build();
        AtomicReference<CommentedConfigurationNode> configuration = new AtomicReference<>(loader.createNode());
        FileManager files = mock(FileManager.class);
        YamlCustomFile yaml = mock(YamlCustomFile.class);
        when(yaml.getConfiguration()).thenAnswer(invocation -> configuration.get());
        when(files.getYamlFile(any())).thenReturn(Optional.of(yaml));
        when(files.saveFile(any())).thenAnswer(invocation -> {
            loader.save(configuration.get());
            return files;
        });
        FusionKyori fusion = mock(FusionKyori.class);
        when(fusion.getDataPath()).thenReturn(directory);
        when(fusion.getFileManager()).thenReturn(files);
        FusionProvider.register(fusion);
        CrazyCratesPlugin<?> plugin = mock(CrazyCratesPlugin.class);
        when(plugin.isCrateAvailable(anyString())).thenReturn(true);
        when(plugin.isCrateAvailable("Unavailable")).thenReturn(false);
        YamlFactory storage = new YamlFactory(plugin);
        List<String> ids = List.of("daily", "vote", "money", "spawner", "rare", "legendary");
        for (int i = 0; i < ids.size(); i++) {
            storage.addCrateLocation("Crate" + i, "spawn", ids.get(i), i, 70, -i);
        }
        require(java.nio.file.Files.isRegularFile(locationFile), "set must save immediately");
        configuration.set(loader.load());
        Map<CrazyLocation, CrateStatus> locations = storage.getCrateLocations();
        require(locations.size() == 6, "all six success entries must survive disk reload");
        require(locations.keySet().stream().map(CrazyLocation::getId).toList().equals(ids), "YAML order must remain stable");
        for (String id : ids) require(storage.getCrateLocation(id).isPresent(), "lookup must find " + id);
        storage.addCrateLocation("Unavailable", "spawn", "disabled-one", 1, 70, 1);
        storage.addCrateLocation("Unavailable", "spawn", "disabled-two", 2, 70, 2);
        storage.addCrateLocation("Crate", "not-yet-loaded-world", "missing-world-one", 3, 70, 3);
        storage.addCrateLocation("Crate", "another-unloaded-world", "missing-world-two", 4, 70, 4);
        for (String id : List.of("broken-one", "broken-two")) {
            configuration.get().node("Locations", id, "Crate").set("Crate");
            configuration.get().node("Locations", id, "World").set("spawn");
        }
        loader.save(configuration.get());
        configuration.set(loader.load());
        locations = storage.getCrateLocations();
        require(locations.size() == 12, "multiple entries of every status must survive");
        require(locations.values().stream().filter(s -> s == CrateStatus.success).count() == 8, "all success entries retained");
        require(locations.values().stream().filter(s -> s == CrateStatus.failed).count() == 2, "all malformed entries retained");
        require(locations.values().stream().filter(s -> s == CrateStatus.unavailable).count() == 2, "all unavailable entries retained");
        require(storage.getCrateLocation("missing-world-one").isPresent(), "unloaded worlds must not erase storage entries");
        require(storage.getCrateLocation("broken-one").isEmpty(), "malformed entries must fail lookup");
        storage.removeCrateLocation("daily");
        configuration.set(loader.load());
        require(storage.getCrateLocation("daily").isEmpty(), "removal must persist immediately");
        require(storage.getCrateLocations().size() == 11, "removal must preserve other entries");
        FusionProvider.unregister();
        Mockito.clearAllCaches();
        System.out.println("PASS: six saved locations reload in order; all success/failed/unavailable entries survive; unloaded-world entries remain; immediate save/removal and per-ID lookup pass.");
    }
    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
