# Feature structure

Each feature owns its UI, state, domain rules, and data access.

```text
features/<feature>/
  data/
    datasources/
    models/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    controllers/
    pages/
    widgets/
```

Rules:

- Pages compose controllers and widgets; they do not contain data parsing.
- Controllers hold UI state and call repositories or use cases.
- Domain code has no Flutter imports.
- Data code converts external formats into domain entities.
- Widgets over roughly 50 lines move into their own file.
- Large standalone modes are loaded through `shell/mode_screen_loader.dart`.
- Cross-feature behaviour belongs in `core/`, `services/`, or `shared/`.
- New code must not add another feature-sized file at the feature root.

Legacy feature-root screens can be migrated incrementally without changing
their public screen class. Start by extracting controllers, then page sections,
then data and domain logic.
