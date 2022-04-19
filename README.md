# botmimic-demo-encoder
#说明
此程序可以将demo文件解析为botmimic所需要的的文件格式
```bash
# 安装依赖
go get -u github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs
```
#使用方法
```bash
go run main.go --file xxxx.dem
```
文件会输出到output文件夹下
#服务器配置
后期将会使用tickrate control按demo的tickrate来控制回放服务器的tickrate
#注意事项
目前只是初步的实现解析功能，相关配套插件还没有实现