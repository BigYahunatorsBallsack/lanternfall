// Minimal Luau host for Lanternfall unit tests: exposes file access and chunk loading to prelude.luau,
// which fakes the Roblox instance tree (script, require, game) on top of the repository's src folder.
// Usage: luau-test-runner <repo-root> <spec files...>

use mlua::{Lua, Table, Value};
use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: luau-test-runner <repo-root> <spec files...>");
        return ExitCode::from(2);
    }
    match run(&args[1], &args[2..]) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::from(1),
        Err(error) => {
            eprintln!("runner error: {error}");
            ExitCode::from(2)
        }
    }
}

fn run(root: &str, specs: &[String]) -> mlua::Result<bool> {
    let lua = Lua::new();
    let globals = lua.globals();

    globals.set(
        "__readFile",
        lua.create_function(|_, path: String| Ok(std::fs::read_to_string(path).ok()))?,
    )?;
    globals.set(
        "__isFile",
        lua.create_function(|_, path: String| Ok(Path::new(&path).is_file()))?,
    )?;
    globals.set(
        "__isDir",
        lua.create_function(|_, path: String| Ok(Path::new(&path).is_dir()))?,
    )?;
    globals.set(
        "__loadChunk",
        lua.create_function(|lua, (source, name, env): (String, String, Table)| {
            lua.load(source).set_name(name).set_environment(env).into_function()
        })?,
    )?;
    globals.set("__root", root)?;

    let prelude = include_str!("../prelude.luau");
    let run_specs: mlua::Function = lua.load(prelude).set_name("=prelude").eval()?;
    let spec_list = lua.create_sequence_from(specs.iter().cloned())?;
    let passed: Value = run_specs.call(spec_list)?;
    Ok(matches!(passed, Value::Boolean(true)))
}
