# 项目需求文档 (prj.md)

## 列表使用规则
1. **有优先级要求的列表**：指导智能体思考分析过程的处理流程等需要优先级的内容，使用数字序号表示优先级，数字越小优先级越高
2. **无优先级要求的列表**：文件结构、项目概述等结构性内容，可以使用无序列表或简单的数字编号（不表示优先级）
3. 有优先级要求的列表，排序基于任务处理的逻辑顺序和重要程度
4. 无优先级要求的列表，使用无序列表或简单的数字编号，仅用于结构组织

## 项目概述
这是一个自动化服务器配置工具，旨在帮助用户快速配置新的云服务器，包括网络代理、远程访问、开发环境等常用配置，实现一键式部署。

## 1. 项目需求
1.1 **核心功能需求**：
1.1.1 自动安装和配置网络代理工具（如clashctl）
1.1.2 自动部署远程访问解决方案（如zerotier、frp）
1.1.3 自动安装和配置Docker环境
1.1.4 自动初始化zsh环境（set -o vi、自定义prompt等）
1.1.5 支持从GitHub拉取项目后一键执行所有配置
1.1.6 提供模块化配置选项，允许用户选择需要的配置项
1.2 **技术需求**：
1.2.1 使用Shell脚本作为主要开发语言，确保跨平台兼容性
1.2.2 采用模块化设计，便于扩展和维护
1.2.3 目前只考虑支持Ubuntu 22.04和Ubuntu 24.04作为目标Linux系统
1.2.4 保留发行版本确认和分支逻辑代码，便于未来扩展支持其他发行版
1.2.5 实现错误处理和日志记录，便于调试
1.3 **安全性需求**：
1.3.1 确保数据安全
1.3.2 防止常见的安全漏洞
1.3.3 遵循安全开发最佳实践

## 2. 项目进度
2.1 **当前阶段**：核心功能开发完成，进入测试和优化阶段
2.2 **已完成工作**：
2.2.1 开发了核心配置脚本 `main.sh`，包含命令行参数解析和主执行流程
2.2.2 实现了模块化配置选项，支持通过 `--modules` 参数指定要执行的模块
2.2.3 完成了配置管理方案，包括默认配置、加密配置和解密流程
2.2.4 开发了加密和解密辅助脚本 `scripts/encrypt.sh` 和 `scripts/decrypt.sh`
2.2.5 实现了远程执行功能，支持将脚本传输到远程服务器并执行
2.2.6 开发了日志记录功能，支持不同日志级别
2.2.7 实现了帮助信息显示，区分本地/远程模式并显示当前主机名
2.2.8 测试了macOS和Linux发行版的兼容性
2.2.9 修复了rsync命令中的参数传递问题，使用数组构建命令确保安全性
2.2.10 在main.sh中添加了-d/-c选项，支持直接解密和加密功能
2.2.11 优化了日志输出，明确区分了未发现解密后的配置文件和发现比加密文件更旧的配置文件
2.2.12 修复了scripts/decrypt.sh脚本的退出码处理，使用return代替exit以确保函数正确返回
2.2.13 在docker.sh中添加了check_installed函数，实现Docker安装状态检测
2.2.14 修改了module.sh中的execute_module函数，添加force参数支持，实现已安装模块自动跳过功能
2.2.15 更新了main.sh支持-f/--force命令行参数，允许用户强制重新安装模块
2.2.16 优化了模块执行逻辑，确保已安装模块在非强制模式下自动跳过安装步骤
2.3 **下一步计划**：
2.3.1 完善各模块的具体实现和测试
2.3.2 测试更多Linux发行版
2.3.3 编写详细的使用文档
2.3.4 在项目完成阶段创建正式README.md文件

## 3. 项目管理
3.1 **角色分工**：
3.1.1 trae-meta智能体：维护trae.md规则文档
3.1.2 trae-prj智能体：根据trae.md规则开发项目
3.1.3 用户：提供需求和协调智能体工作
3.2 **沟通机制**：
3.2.1 通过用户作为中介进行间接协作
3.2.2 定期更新文档状态
3.2.3 及时反馈项目进展

## 4. 技术方案
4.1 **项目结构**：
```
./
├── prj.md               # 项目需求文档
├── trae.md              # 任务处理规则
├── trae_meta_prompt.md  # trae-meta智能体提示词
├── trae_prj_prompt.md   # trae-prj智能体提示词
├── main.sh              # 主配置脚本
├── lib/                 # 核心库文件目录
│   ├── common.sh        # 通用函数库
│   ├── config.sh        # 配置处理库
│   ├── module.sh        # 模块管理库
│   └── remote.sh        # 远程执行库
├── modules/             # 模块化配置脚本目录
│   ├── docker.sh        # Docker配置模块
│   └── zsh.sh           # ZSH配置模块
├── config/              # 配置文件目录
│   ├── default.conf     # 默认配置
│   ├── default.conf.template  # 配置模板
│   └── enc.conf.enc     # 加密配置文件
├── scripts/             # 辅助脚本目录
│   ├── decrypt.sh       # 解密脚本
│   └── encrypt.sh       # 加密脚本
├── logs/                # 日志目录
└── .gitignore           # Git忽略文件
```
4.2 **配置管理方案**：
- **配置文件说明**：
  - `config/default.conf.template`：配置模板文件，包含所有可用配置项（含加密变量和环境检测变量）
  - `config/default.conf`：默认配置文件，作为开发阶段实例，包含所有环境变量且默认被使用
  - `config/enc.conf.enc`：使用AES-256算法加密的敏感配置文件，包含敏感信息
  - `config/enc.conf`：解密后的明文配置文件（运行时生成，不会被git跟踪），存储解密后的明文加密环境变量用于重写

- **配置加载流程**：
  1. 加载默认配置文件 `default.conf` 作为基础配置
  2. 如果提供了加密密钥（CONFIG_KEY环境变量），则解密 `config/enc.conf.enc` 到 `config/enc.conf`
  3. 加载解密后的 `config/enc.conf`，覆盖基础配置中的相应项
  4. 允许通过命令行参数覆盖任意配置项

- **git忽略**：将加密配置文件 (`config/enc.conf.enc`)、解密配置文件 (`config/enc.conf`) 和日志文件 (`logs/`) 添加到 `.gitignore`，避免将敏感信息和日志提交到GitHub

- **环境变量说明**：所有可用的环境变量及其详细含义可在 `config/default.conf.template` 文件中查看

4.3 **执行流程**：
1. 用户从GitHub拉取项目
2. 执行main.sh脚本，可提供命令行参数和环境变量
3. 脚本加载库文件和日志配置
4. 解析命令行参数（-h, --help, -l, --log-level, -t, --test, --modules, -d/--decrypt, -c/--encrypt）
5. 如果指定了-d/--decrypt选项：
   - 执行解密功能，解密config/enc.conf.enc到config/enc.conf
   - 解密完成后退出
6. 如果指定了-c/--encrypt选项：
   - 执行加密功能，加密config/enc.conf到config/enc.conf.enc
   - 加密完成后退出
7. 如果是远程模式（IS_EXECUTION_ENVIRONMENT=false）：
   - 将项目文件压缩并通过rsync传输到目标主机
   - 在目标主机上解压并执行脚本
   - 传递SSH_CLIENT_HOST环境变量以标识远程会话
8. 如果是本地模式：
   - 检测当前操作系统（支持Linux和macOS）
   - 加载默认配置文件
   - 如果提供了CONFIG_KEY，解密并加载加密配置文件
   - 按照顺序执行指定的模块
9. 生成配置日志
10. 显示执行结果和帮助信息

4.4 **远程执行流程**：
1. 本地脚本检测到IS_EXECUTION_ENVIRONMENT=false
2. 收集目标主机信息（用户名、主机名、端口）
3. 压缩项目文件为tar.gz格式
4. 使用rsync将压缩文件传输到目标主机临时目录
5. 解压压缩文件到目标目录
6. 修改远程配置文件，设置IS_EXECUTION_ENVIRONMENT=true
7. 获取本地主机名，通过SSH_CLIENT_HOST环境变量传递
8. 执行SSH命令连接到目标主机并执行脚本
9. 执行完成后保留远程项目文件

4.5 **帮助信息流程**：
1. 用户执行`./main.sh -h`或`./main.sh --help`
2. 脚本调用display_usage函数
3. 显示工具名称和版本信息
4. 检测是否为远程模式（通过SSH_CLIENT_HOST环境变量）
5. 显示当前执行模式和主机名信息
6. 显示使用方法、选项列表和示例，包括新增的-d/-c选项
7. 如果是远程模式，显示客户端主机信息

4.4 **智能体参与构建的文件位置**：
- Trae AI相关文件直接存放在项目根目录
- 包括：trae.md、prj.md、trae_meta_prompt.md、trae_prj_prompt.md
- 这些文件不会被添加到 `.gitignore`，会作为开发项目的历史资料保留在仓库中
- 项目完成后，这些文件可以继续保留用于后续维护

## 5. 配置模板设计
5.1 **配置模板**：配置模板文件 `config/default.conf.template` 包含所有可用的配置项定义，用户可以根据需要参考该文件了解所有支持的环境变量。

5.2 **加密变量命名规范**

加密变量格式为：`${module}_ENC_${varname}`

示例：
- `CLASHCTL_ENC_URL`：加密的Clashctl二进制文件下载地址
- `ZEROTIER_ENC_NETWORK_ID`：加密的Zerotier网络ID
- `FRP_ENC_AUTH_TOKEN`：加密的FRP认证令牌

5.3 **配置加密机制**：
- **加密算法**：使用AES-256-CBC算法结合PBKDF2密钥派生
- **安全性**：
  - PBKDF2使用100000次迭代增强安全性
  - 每个加密文件都有唯一的随机盐值
  - 加密过程中使用了初始化向量(IV)
- 加密脚本 (`scripts/encrypt.sh`)：
  - 支持从环境变量或命令行输入获取密钥
  - 将提示信息输出到标准错误流，避免干扰加密输出
  - 使用安全的PBKDF2密钥派生
  - 支持自定义密钥环境变量名

- 解密脚本 (`scripts/decrypt.sh`)：
  - 支持从环境变量或命令行输入获取密钥
  - 将提示信息输出到标准错误流，避免干扰解密输出
  - 使用安全的PBKDF2密钥派生
  - 支持自定义密钥环境变量名
  - 解密成功时返回0，失败时返回1

- 主脚本解密流程：
  - 检测加密配置文件`config/enc.conf.enc`是否存在
  - 如果存在，检查解密后的配置文件`config/enc.conf`是否存在且比加密文件更新
  - 如果解密后的文件不存在或比加密文件旧，则进行解密
  - 解密时记录详细日志，明确说明解密原因
  - 解密成功后，通过source命令加载配置变量
  - 解密失败则输出错误信息并继续执行（使用默认配置）
  - 支持通过`-d`选项手动触发解密
  - 支持通过`-c`选项手动触发加密

5.4 **敏感信息处理**
- 所有敏感配置项都以`_ENC_`后缀标识，格式为`${module}_ENC_${varname}`
- 敏感信息可以在`default.conf`中以占位符`!!!!!!!ENCRYPTED!!!!!!!`或空的形式存在
- 加密后的配置文件会被git跟踪，便于团队共享
- 解密后的配置文件不会被git跟踪，确保安全

## 6. README.md结构设计
**注意**：除非项目标记为完成阶段，否则不应该创建正式的README.md文件。

README.md将包含以下内容：
1. 项目简介
2. 功能特性
3. 支持的Linux发行版：目前仅支持Ubuntu 22.04和Ubuntu 24.04
4. 快速开始
   - 从GitHub拉取项目
   - 配置说明
   - 执行配置
5. 详细配置指南
   - 模块说明
   - 配置参数详解
6. 高级用法
   - 模块化配置
   - 加密配置管理
7. 故障排除
8. 贡献指南
9. 许可证

## 7. 智能体相关文件处理
7.1 **Trae AI文件位置**：
- 所有Trae AI相关文件直接存放在项目根目录
- 包含：trae.md、prj.md、trae_meta_prompt.md、trae_prj_prompt.md

7.2 **Git忽略策略**：
```gitignore
# .gitignore

# 配置文件
config/enc.conf.enc  # 加密配置文件（会被git跟踪）
config/enc.conf       # 解密配置文件（运行时生成，不被git跟踪）

# 日志文件
logs/

# 临时文件
*.tmp
*.swp
```

## 8. 使用示例
```bash
# 从GitHub拉取项目
git clone https://github.com/user/tlnx.git
cd tlnx

# 本地执行一键配置（使用默认配置）
bash main.sh

# 本地执行一键配置（使用加密配置）
CONFIG_KEY=your-secret-key bash main.sh

# 本地执行一键配置（测试模式，不实际执行操作）
bash main.sh -t

# 本地执行一键配置（设置日志级别为DEBUG）
bash main.sh -l DEBUG

# 显示帮助信息
bash main.sh -h

# 远程执行（通过配置文件指定目标主机）
# 首先在config/default.conf中设置：
# IS_EXECUTION_ENVIRONMENT=false
# TARGET_HOST=your-server-ip
# TARGET_USER=your-username
# TARGET_PORT=22（可选）
bash main.sh

# 远程执行特定模块
bash main.sh --modules docker,zsh

# 使用新增的-d选项解密配置文件
bash main.sh -d

# 使用新增的-c选项加密配置文件
bash main.sh -c

# 使用环境变量密钥解密配置文件
CONFIG_KEY=your-secret-key bash main.sh -d

# 使用环境变量密钥加密配置文件
CONFIG_KEY=your-secret-key bash main.sh -c

# 执行特定模块
bash main.sh --modules docker,zsh
```
```