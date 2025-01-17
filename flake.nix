{
  description = "Opinionated Sphinx Shell";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/nixos-22.11";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    bpmn-to-image = {
      url = "github:bpmn-io/bpmn-to-image";
      flake = false;
    };
    dmn-to-html = {
      url = "github:datakurre/dmn-to-html";
      flake = false;
    };
    form-js-to-image = {
      url = "github:datakurre/form-js-to-image";
      flake = false;
    };
    lezer-feel = {
      url = "github:nikku/lezer-feel";
      flake = false;
    };
    robot-task = {
      url = "github:datakurre/camunda-modeler-robot-plugin";
      flake = false;
    };
    npmlock2nix = {
      url = "github:nix-community/npmlock2nix";
      flake = false;
    };
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        legacy = import inputs.nixpkgs-legacy {
          inherit system;
        };
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              inherit (legacy) nodejs-14_x nodejs-16_x;
            })
          ];
        };
        python = pkgs.python3;
        workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.;
        };
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };
        pythonSet =
          (pkgs.callPackage inputs.pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              pkgs.lib.composeManyExtensions [
                inputs.pyproject-build-systems.overlays.default
                overlay
                (final: prev: { })
              ]
            );
        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };
        editablePythonSet = pythonSet.overrideScope editableOverlay;
        pyprojectName = (builtins.fromTOML (builtins.readFile (./. + "/pyproject.toml"))).project.name;
        virtualenv = editablePythonSet.mkVirtualEnv "${pyprojectName}-dev-env" workspace.deps.all;
      in
      {
        packages.uv = pkgs.buildFHSEnv {
          name = "uv";
          targetPkgs = pkgs: [
            pkgs.uv
            python
          ];
          runScript = "uv";
        };
        packages.bpmn-to-image = (import inputs.npmlock2nix { inherit pkgs; }).v1.build rec {
          src = inputs.bpmn-to-image;
          preBuild = ''
            export HOME=$(mktemp -d)
          '';
          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp -a node_modules $out/lib
            cp -a cli.js $out/bin/bpmn-to-image
            cp -a index.js $out/lib
            cp -a skeleton.html $out/lib
            cp ${inputs.robot-task}/dist/module-iife.js $out/lib/robot-task.js
            substituteInPlace $out/bin/bpmn-to-image \
              --replace "'./'" \
                        "'$out/lib'"
            substituteInPlace $out/lib/index.js \
              --replace "puppeteer.launch();" \
                        "puppeteer.launch({executablePath: '${pkgs.chromium}/bin/chromium'});" \
              --replace "await loadScript(viewerScript);" \
                        "await loadScript(viewerScript); await loadScript('$out/lib/robot-task.js')" \
              --replace "module.exports.convertAll = convertAll;" \
                        "module.exports.convertAll = async (conversions, options={}) => { await convertAll(conversions, options); process.exit(0); };"

            substituteInPlace $out/lib/skeleton.html \
              --replace "container: '#canvas'" \
                        "container: '#canvas', additionalModules: [ RobotTaskModule ]"
            wrapProgram $out/bin/bpmn-to-image \
              --set PATH ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
              --set NODE_PATH $out/lib/node_modules
          '';
          buildInputs = [ pkgs.makeWrapper ];
          buildCommands = [ ];
          node_modules_attrs = {
            PUPPETEER_SKIP_DOWNLOAD = "true";
          };
        };
        packages.dmn-to-html = (import inputs.npmlock2nix { inherit pkgs; }).v1.build rec {
          src = inputs.dmn-to-html;
          preBuild = ''
            export HOME=$(mktemp -d)
          '';
          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp -a node_modules $out/lib
            cp -a cli.js $out/bin/dmn-to-html
            cp -a index.js $out/lib
            cp -a skeleton.html $out/lib
            substituteInPlace $out/bin/dmn-to-html \
              --replace "'./'" \
                        "'$out/lib'"
            substituteInPlace $out/lib/index.js \
              --replace "puppeteer.launch();" \
                        "puppeteer.launch({executablePath: '${pkgs.chromium}/bin/chromium'});"
            wrapProgram $out/bin/dmn-to-html \
              --set PATH ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
              --set NODE_PATH $out/lib/node_modules
          '';
          buildInputs = [ pkgs.makeWrapper ];
          buildCommands = [ ];
          node_modules_attrs = {
            PUPPETEER_SKIP_DOWNLOAD = "true";
          };
        };
        packages.form-js-to-image = (import inputs.npmlock2nix { inherit pkgs; }).v1.build rec {
          src = inputs.form-js-to-image;
          preBuild = ''
            export HOME=$(mktemp -d)
          '';
          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp -a node_modules $out/lib
            cp -a cli.js $out/bin/form-to-image
            cp -a index.js $out/lib
            cp -a skeleton.html $out/lib
            substituteInPlace $out/bin/form-to-image \
              --replace "'./'" \
                        "'$out/lib'"
            substituteInPlace $out/lib/index.js \
              --replace "puppeteer.launch();" \
                        "puppeteer.launch({executablePath: '${pkgs.chromium}/bin/chromium'});"
            wrapProgram $out/bin/form-to-image \
              --set PATH ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
              --set NODE_PATH $out/lib/node_modules
          '';
          buildInputs = [ pkgs.makeWrapper ];
          buildCommands = [ ];
          node_modules_attrs = {
            PUPPETEER_SKIP_DOWNLOAD = "true";
          };
        };
        packages.feel-tokenizer = (import inputs.npmlock2nix { inherit pkgs; }).v2.build {
          src = inputs.lezer-feel;
          preBuild = ''
            export HOME=$(mktemp -d)
          '';
          installPhase = ''
                    mkdir -p $out/bin $out/lib $out/lib/lezer-feel/lezer-feel
                    cp -a package.json $out/lib/lezer-feel/lezer-feel
                    cp -a dist $out/lib/lezer-feel/lezer-feel
                    cp -a node_modules $out/lib
                    cat > $out/bin/feel-tokenizer << EOF
            #!/usr/bin/env node
            const classHighlighter = require("@lezer/highlight").classHighlighter;
            const highlightTree = require("@lezer/highlight").highlightTree;
            const parser = require('lezer-feel').parser;
            const source = require('fs').readFileSync(0, 'utf-8');
            console.log(JSON.stringify(((source, tree) => {
              const children = [];
              let index = 0;
              highlightTree(tree, classHighlighter, (from, to, classes) => {
                if (from > index) {
                  children.push({
                    type: "text",
                    index: index,
                    value: source.slice(index, from)
                  })
                }
                children.push({
                  type: classes.replace(/tok-/g, ""),
                  index: from,
                  children: [{
                    type: "text",
                    index: from,
                    value: source.slice(from, to)
                  }]
                });
                index = to;
              });
              if (index < source.length) {
                children.push({
                  type: "text",
                  index: index,
                  value: source.slice(index)
                });
              }
              return children;
            })(source, parser.parse(source))));
            EOF
                    chmod u+x $out/bin/feel-tokenizer
                    wrapProgram $out/bin/feel-tokenizer \
                      --set PATH ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
                      --set NODE_PATH $out/lib/lezer-feel:$out/lib/node_modules
          '';
          buildInputs = [ pkgs.makeWrapper ];
          buildCommands = [ "npm run build" ];
          node_modules_attrs = {
            preBuild = ''
              cp package.json x; rm package.json; mv x package.json
              substituteInPlace package.json \
                --replace "run-s build" "echo run-s build"
            '';
          };
        };

        overlays.default = final: prev: {
          inherit (self.packages.${system})
            bpmn-to-image
            form-js-to-image
            dmn-to-html
            feel-tokenizer
            ;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            virtualenv
            self.packages.${system}.uv
            self.packages.${system}.feel-tokenizer
            self.packages.${system}.bpmn-to-image
            self.packages.${system}.form-js-to-image
            self.packages.${system}.dmn-to-html
            pkgs.imagemagick
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;

      }
    );
}
