# Architecture Rules

## Project Type

Python project.

## Boundaries

<!-- inferred from directory structure -->
- 模块之间不应直接相互导入循环依赖
- 配置文件不应修改业务逻辑
- 构建相关文件（Makefile, Package.swift, pom.xml）不允许直接修改

## Source

- generated_by_hermes
- confidence: low
- needs_confirmation: [architecture interpretation, layer boundaries]
