# Testing Game Systems

## References
- **GUT 9.6.0 Quick Start** — https://gut.readthedocs.io/en/latest/Quick-Start.html — Official GUT docs; setup, assertions, CLI, doubling, parameterized tests
- **GUT 9.6.0 Asserts & Methods** — https://gut.readthedocs.io/en/latest/Asserts-and-Methods.html — Full reference for all GUT assertion methods including signal asserts
- **GUT 9.6.0 Doubles (Mock/Stub/Spy)** — https://gut.readthedocs.io/en/latest/Doubles.html — Full and partial doubles, stubbing return values, spying on calls
- **GUT 9.6.0 Awaiting** — https://gut.readthedocs.io/en/latest/Awaiting.html — `wait_seconds`, `wait_frames`, `wait_for_signal`, `wait_until` patterns
- **GUT 9.6.0 CLI** — https://gut.readthedocs.io/en/ladge/Command-Line.html — Running GUT from CLI for CI/CD
- **GdUnit4 Home** — https://godot-gdunit-labs.github.io/gdUnit4/latest/ — Feature-rich: mocking, spying, scene runner, fuzzing, fluent asserts, C# support
- **GdUnit4 Mocking** — https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/mock/ — Mock creation, verify, argument matchers, working modes
- **GdUnit4 Signals** — https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/signals/ — `assert_signal().is_emitted()`, `monitor_signals()`
- **GdUnit4 CI** — https://godot-gdunit-labs.github.io/gdUnit4/latest/faq/ci/ — GitHub Action and GitLab CI integration
- **GdUnit4 GitHub Action** — https://github.com/godot-gdunit-labs/gdUnit4-action — Official GH action for running GdUnit4 tests in CI
- **WAT (Godot 3 only)** — https://github.com/watplugin/wat — Lightweight plugin, editor-integrated, **not compatible with Godot 4**
- **Godot CLI: `--script` / `--headless`** — https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html — Running `.gd` scripts from CLI as SceneTree or MainLoop
- **Godot CLI Tutorial** — https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html — `--headless`, `--script`, `--check-only` flags
- **godot-ci Docker image** — https://github.com/abarichello/godot-ci — Pre-built Docker images for Godot CI (export, test)
- **setup-godot action** — https://github.com/lihop/setup-godot — GH action to install Godot binary with optional export templates
- **khirsahdev/godot-runtime-test** — https://github.com/khirsahdev/godot-runtime-test — CLI-based runtime testing: inject properties, assert signals via command line

## Recommended Pattern

For a Godot 4 2D game, **GUT (Godot Unit Test) 9.x** is the most mature, well-documented, and widely adopted testing framework. It is the recommended choice because:

- Actively maintained (v9.6.0 as of Feb 2026, supports Godot 4.6)
- Rich assertion library — 40+ assert methods including signal testing
- Doubling (mocks/stubs/spies) — full doubles, partial doubles, parameter stubbing
- Async support — `wait_seconds`, `wait_frames`, `wait_for_signal`, `wait_until`
- CLI runner for CI/CD — `godot --headless -s addons/gut/gut_cmdln.gd`
- JUnit XML export for CI reporting
- Inner test classes for organization
- Parameterized tests

**GdUnit4** is the strongest alternative with more advanced features (fluent assertions, built-in mocking, scene runner with input simulation, fuzzing, C# support) but has a larger footprint and steeper learning curve.

**Scene-based auto-run tests** (a plain `SceneTree` script with print-based assertions) are the simplest approach and work well for integration tests where you need a full scene tree.

For this project (Godot 4, 2D, GDScript), use GUT for unit tests and scene-based auto-run scripts for integration/system tests.

## Implementation Patterns

### GUT-Based Tests
- Install via Asset Library (`GUT - Godot Unit Testing`) or git submodule
- Enable plugin in Project Settings → Plugins
- Test files extend `GutTest`, placed in `res://test/unit/` or `res://test/integration/`
- Methods prefixed with `test_` are auto-discovered
- Setup/teardown: `before_all`, `before_each`, `after_each`, `after_all`
- Use `add_child_autofree(node)` for Node subclass instances (auto-freed after each test)
- Use `double(path)` for mock objects, `stub(obj, method).to_return(val)` for stubbing
- Signal testing: `watch_signals(obj)` → action → `assert_signal_emitted(obj, "signal_name")`

### WAT-Based Tests
- **Not available for Godot 4** — WAT last release (v4.2.2) only supports Godot 3.x
- Mentioned for historical context; do not use for Godot 4 projects

### Scene-Based Auto-Run Tests
- Create a `.tscn` with a root node that has a script extending `Node`
- Script handles test lifecycle in `_ready()` or with timers
- Use `print()` statements for reporting pass/fail
- Run with: `godot --headless --scene res://scenes/test_whatever.tscn 2>&1 | grep "TEST"`
- Good for: integration tests, combat demos, wave spawning verification
- Pattern: auto-place entities, wait via `await get_tree().create_timer(n).timeout`, assert with `print()`, call `get_tree().quit()` to exit

### CLI Test Runner Pattern
- GUT CLI: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -glog=2 -gexit`
- GdUnit4 CLI: `./addons/gdUnit4/runtest.sh -a res://tests/`
- Plain script runner: `godot --headless -s test_runner.gd` (script must extend `SceneTree`)
- Filter by file: `-gtest=res://test/unit/test_foo.gd`
- Filter by method: `-gunit_test_name=test_specific_thing`
- JUnit output: `-gjunit_xml_file=results.xml`

### CI/CD Integration
- **GitHub Actions**: Use `lihop/setup-godot@v3` to install Godot, then run GUT CLI
- **Docker**: `barichello/godot-ci:4.3` image has Godot pre-installed
- **GdUnit4 Action**: `godot-gdunit-labs/gdUnit4-action@v1` — one-step setup
- Always use `--headless` flag to avoid display issues
- Use `xvfb-run` if Godot still requires a display (older versions)
- Filter `grep` output to capture only test results in CI logs

## Code Snippet Examples

### GUT Test Script Example
```gdscript
# res://test/unit/test_combat.gd
extends GutTest

const Enemy = preload("res://scripts/enemy.gd")
const Unit = preload("res://scripts/foot_soldier.gd")

func before_each():
    # GUT auto-frees doubled instances; use add_child_autofree for nodes
    pass

func test_unit_takes_damage():
    var enemy = Enemy.new()
    add_child_autofree(enemy)

    var initial_hp = enemy.hit_points
    enemy.take_damage(10)

    assert_eq(enemy.hit_points, initial_hp - 10, "HP should decrease by 10")

func test_enemy_dies_at_zero_hp():
    var enemy = Enemy.new()
    add_child_autofree(enemy)

    enemy.take_damage(999)

    assert_true(enemy.is_dead(), "Enemy should be dead after fatal damage")

func test_signal_emitted_on_death():
    var enemy = Enemy.new()
    add_child_autofree(enemy)
    watch_signals(enemy)

    enemy.take_damage(999)

    assert_signal_emitted(enemy, "died", "Enemy should emit died signal")

func test_doubled_dependency():
    var dbl = double(Enemy).new()
    stub(dbl, "get_defense").to_return(5)
    # dbl.get_defense() now returns 5 without executing real code
    assert_eq(dbl.get_defense(), 5)

func test_parameterized(values = use_parameters([[1,2], [3,4], [5,6]])):
    assert_eq(values[0] + values[1], values[0] + values[1])
```

### Scene-Based Auto-Test Example
```gdscript
# scripts/test_minimal.gd (attached to a Node in test_minimal.tscn)
extends Node

func _ready():
    print("MINIMAL TEST: Starting")
    _run_test()

func _run_test():
    var enemy = preload("res://scripts/enemy.gd").new()
    add_child(enemy)

    var unit = preload("res://scripts/foot_soldier.gd").new()
    add_child(unit)

    # Wait for combat to resolve
    await get_tree().create_timer(5.0).timeout

    if enemy.is_dead():
        print("MINIMAL TEST: PASS - Enemy died")
    else:
        print("MINIMAL TEST: FAIL - Enemy still alive (HP: " + str(enemy.hit_points) + ")")

    get_tree().quit()
```

### GUT CLI Runner (CI)
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd \
  -gdir=res://test \
  -glog=2 \
  -gexit \
  -gjunit_xml_file=test-results.xml
```

### CI YAML Example (GitHub Actions)
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true
      - name: Setup Godot
        uses: lihop/setup-godot@v3
        with:
          version: 4.3-stable
      - name: Run GUT tests
        run: |
          godot --headless -d -s addons/gut/gut_cmdln.gd \
            -gdir=res://test \
            -glog=2 \
            -gexit \
            -gjunit_xml_file=test-results.xml
      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results.xml
```

### CI YAML Example (GdUnit4)
```yaml
name: GdUnit4 Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: godot-gdunit-labs/gdUnit4-action@v1
        with:
          godot-version: '4.2.1'
          paths: 'res://tests'
          timeout: 10
          report-name: test-report.xml
```

### Signal Testing with `wait_for_signal`
```gdscript
# GUT: wait for signal with timeout
func test_signal_within_timeframe():
    var obj = MyClass.new()
    add_child_autofree(obj)

    obj.start_something()
    var was_emitted = await wait_for_signal(obj.some_signal, 5.0)

    assert_true(was_emitted, "Signal should emit within 5 seconds")
    assert_signal_emitted_with_parameters(obj, "some_signal", ["expected_arg"])
```

### Testing `_process`-Dependent Logic
```gdscript
# Use GUT's wait_frames or wait_seconds to let _process run
func test_accumulated_delta():
    var obj = MyMovingNode.new()
    add_child_autofree(obj)

    obj.position = Vector2.ZERO
    obj.speed = 100.0

    # Wait 10 frames so _process accumulates delta
    await wait_frames(10)

    assert_true(obj.position.length() > 0, "Object should have moved")
```

### Testing Autoloads/Singletons
```gdscript
# Autoloads are globally accessible; create a fresh instance for test isolation
func test_game_manager_gold():
    var gm = preload("res://scripts/game_manager.gd").new()
    # Don't use add_child_autofree — autoloads are not always Nodes
    # Use autofree for RefCounted objects
    gm.reset()  # if available

    gm.add_gold(100)
    assert_eq(gm.gold, 100)
```

### print() vs assert() vs GUT Assertions
```gdscript
# print() — for scene-based/integration tests, pipe output to grep
print("TEST PASS: Enemy died correctly")

# assert() — built-in GDScript, crashes on failure, hard to recover
assert(enemy.hp == 0)

# GUT assertions — soft failures, continue to next test, detailed messages
assert_eq(enemy.hp, 0, "Enemy should be dead")
assert_gt(unit.hp, 0, "Unit should survive")
```

## Limitations

- **No real mocking framework in GDScript** — GUT's doubling and GdUnit4's mock both work by generating wrapper classes at runtime. Native/built-in Godot methods cannot be mocked or spied on (e.g., `set_position`, `queue_free`). Core function overwriting is blocked by the engine.
- **No exceptions in GDScript** — Cannot use try/catch. GUT and GdUnit4 handle failures by printing and continuing; you must use fail-fast patterns explicitly.
- **No reflection/introspection** — Limited ability to inspect private variables or internal state without adding accessor methods.
- **SceneTree dependency** — Nodes must be added to the tree for `_process`, `_physics_process`, timers, and signals to work. This adds complexity to unit tests (need `add_child_autofree`).
- **Headless mode quirks** — `--headless` may not work reliably across all Godot 4.x versions (bug reports exist for v4.3). Workaround: use `xvfb-run` on Linux CI runners.
- **Autoload singletons** — Cannot be easily tested in isolation since they persist across the Godot session. Pattern: use a test-specific instance rather than the autoloaded one.
- **Orphan node detection** — Nodes not properly freed cause test pollution. GUT provides `assert_no_new_orphans()`. GdUnit4 auto-frees mock instances.
- **No test coverage tools** — No built-in code coverage analysis for GDScript tests. Third-party tooling does not exist.
- **Slow test startup** — Each Godot CLI invocation has ~1-2s startup overhead. Organize many small assertions into fewer test files to minimize total runtime.

## Alternatives

- **GdUnit4** — Most feature-rich alternative. Fluent assertions, built-in mocking/spying, scene runner with input simulation (mouse clicks, keyboard), fuzzing, parameterized tests, C# support, GitHub Action. Requires Godot 4.3+. Steeper learning curve but more powerful than GUT.
- **Scene-based auto-run tests** (no plugin) — Simplest approach. Create `.tscn` files with `Node` scripts that auto-run in `_ready()`. No assertions library needed; use `print()` + `grep` for pass/fail. Best for integration/system tests. Pattern already used in this project (e.g., `test_combat.tscn`).
- **khirsahdev/godot-runtime-test** — CLI-based runtime testing. Inject properties, call methods, and assert signals without modifying source files. Useful for AI agents or quick debugging. Run with: `godot --path . --headless scene.tscn -- --set:.:health=50 --expect:.:health=50`
- **Godot built-in `--check-only`** — Syntax-check scripts only. Not a testing framework, but useful for catching compilation errors in CI: `godot --path . --check-only -s res://scripts/some_script.gd`
- **Manual `SceneTree` script runner** — Extend `SceneTree` directly (not `Node`), override `_init()` for setup, call `quit()` when done. No scenes needed. Good for headless batch tests. Example:
  ```gdscript
  extends SceneTree
  func _init():
      print("Running test...")
      # test logic here
      quit()
  ```
  Run: `godot --headless -s test_runner.gd`
