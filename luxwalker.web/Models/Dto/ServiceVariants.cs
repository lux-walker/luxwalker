public record ServiceVariantGroup(string Name, ServiceVariant[] Children);
public record ServiceVariant(string Name, int Type, int Id);