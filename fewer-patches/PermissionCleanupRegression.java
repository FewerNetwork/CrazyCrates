import com.badbones69.crazycrates.paper.CrazyCrates;
import com.badbones69.crazycrates.paper.api.CrazyCratesPaper;
import com.badbones69.crazycrates.paper.utils.MiscUtils;
import org.bukkit.Server;
import org.bukkit.plugin.PluginManager;
import org.bukkit.permissions.Permission;
import org.mockito.MockedStatic;
import static org.mockito.Mockito.*;
public class PermissionCleanupRegression {
 public static void main(String[] args) {
  CrazyCrates plugin=mock(CrazyCrates.class);
  CrazyCratesPaper platform=mock(CrazyCratesPaper.class,RETURNS_DEEP_STUBS);
  Server server=mock(Server.class);PluginManager manager=mock(PluginManager.class);
  
  when(plugin.getPlatform()).thenReturn(platform);when(plugin.getServer()).thenReturn(server);when(server.getPluginManager()).thenReturn(manager);
  try(MockedStatic<CrazyCrates> mocked=mockStatic(CrazyCrates.class)) {
   mocked.when(CrazyCrates::getPlugin).thenReturn(plugin);
   for(String crate:new String[]{"Basic","CasinoCrate","Epic","Legendary","Rare","Spawner","vote"})
    for(int i=1;i<=20;i++)MiscUtils.unregisterPermission("crazycrates.respin."+crate+"."+i);
   verify(manager,never()).removePermission(anyString());
   verifyNoInteractions(platform.getFusion());
   String node="crazycrates.respin.Basic.1";when(manager.getPermission(node)).thenReturn(new Permission(node)).thenReturn(null);
   MiscUtils.unregisterPermission(node);MiscUtils.unregisterPermission(node);
   verify(manager,times(1)).removePermission(node);
   verify(manager,never()).addPermission(any());
   MiscUtils.unregisterPermission("");
  }
  System.out.println("PASS:140 absent disabled nodes no-op; present node removed once; repeated cleanup no-op; no authority granted.");
 }
}
