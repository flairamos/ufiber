#!/bin/bash

# 提示用户输入文件名
echo "请输入Go文件的名称（不包括扩展名，例如：main）："
read fileName

# 如果用户未输入文件名，默认使用test
if [ -z "$fileName" ]; then
    fileName="test"
fi

echo "请输入Go项目的模块名(go mod 文件的名称)"
read modeName

# 将文件名的首字母转为大写
capitalizedFileName="${fileName^}"

handler="./internal/handler"
model="./internal/model"
router="./internal/router"
service="./internal/service"

if [ ! -d "$handler" ]; then
    mkdir -p "$handler"
fi

if [ ! -d "$model" ]; then
    mkdir -p "$model"
fi

if [ ! -d "$router" ]; then
    mkdir -p "$router"
fi

if [ ! -d "$service" ]; then
    mkdir -p "$service"
fi



# handler 开始
handlerContent="package $(basename $handler)

import (
	\"github.com/gofiber/fiber/v2\"
	\"$modeName/internal/model\"
	\"$modeName/internal/service\"
	\"$modeName/pkg/respond\"
)

// ${capitalizedFileName}Add 添加
func ${capitalizedFileName}Add(c *fiber.Ctx) error {

	var req model.${capitalizedFileName}Add

	if err := c.BodyParser(&req); err != nil {
		return respond.Fail(c, \"参数错误\", err)
	}

    resp := service.${capitalizedFileName}Add(req)
	return respond.Do(c, resp)
}


// ${capitalizedFileName}Edit 修改
func ${capitalizedFileName}Edit(c *fiber.Ctx) error {

	var req model.${capitalizedFileName}Edit

	if err := c.BodyParser(&req); err != nil {
		return respond.Fail(c, \"参数错误\", err)
	}

    resp := service.${capitalizedFileName}Edit(req)
	return respond.Do(c, resp)
}


// ${capitalizedFileName}Delete 删除
func ${capitalizedFileName}Delete(c *fiber.Ctx) error {

	var req model.${capitalizedFileName}Delete

	if err := c.BodyParser(&req); err != nil {
		return respond.Fail(c, \"参数错误\", err)
	}

    resp := service.${capitalizedFileName}Delete(req)
	return respond.Do(c, resp)
}

// ${capitalizedFileName}Get 查询
func ${capitalizedFileName}Get(c *fiber.Ctx) error {

	var req model.${capitalizedFileName}Get

	if err := c.QueryParser(&req); err != nil {
		return respond.Fail(c, \"参数错误\", err)
	}

    resp := service.${capitalizedFileName}Get(req)
	return respond.Do(c, resp)
}


// ${capitalizedFileName}Form 精准查询
func ${capitalizedFileName}Form(c *fiber.Ctx) error {

	var req model.${capitalizedFileName}Form

	if err := c.QueryParser(&req); err != nil {
		return respond.Fail(c, \"参数错误\", err)
	}

    resp := service.${capitalizedFileName}Form(req)
	return respond.Do(c, resp)
}
"
# handler 结束

# model 开始
modelContent="package $(basename $model)

// ${capitalizedFileName} 数据库映射
type ${capitalizedFileName} struct {
}

// ${capitalizedFileName}Add 添加参数
type ${capitalizedFileName}Add struct {
}


// ${capitalizedFileName}Edit 编辑参数
type ${capitalizedFileName}Edit struct {
    Id   string \`json:\"id,omitempty\"\`
}

// ${capitalizedFileName}Get 请求参数
type ${capitalizedFileName}Get struct {
    Id   string \`json:\"id,omitempty\"\`
    Page int \`json:\"page,omitempty\"\`
    Limit int \`json:\"limit,omitempty\"\`
}

// ${capitalizedFileName}Delete 删除参数
type ${capitalizedFileName}Delete struct {
    IdStr []string \`json:\"id_str,omitempty\"\`
    IdInt []int \`json:\"id_int,omitempty\"\`
}

// ${capitalizedFileName}Form 编辑参数
type ${capitalizedFileName}Form struct {
    Id   string \`json:\"id,omitempty\"\`
}

// ${capitalizedFileName}Resp 添加返回参数
type ${capitalizedFileName}Resp struct {
}
"

# model 结束

# router 开始
routerContent="package $(basename $router)

import(
	\"github.com/gofiber/fiber/v2\"
    \"$modeName/internal/handler\"
)

// ${fileName} 路由，记得把 ${fileName}(app) 添加把 router.go 中
func ${fileName^}(app *fiber.App) {

	${fileName}Router := app.Group(\"/${fileName}\")
	{
		${fileName}Router.Post(\"/add\", handler.${capitalizedFileName}Add)
		${fileName}Router.Post(\"/edit\", handler.${capitalizedFileName}Edit)
		${fileName}Router.Post(\"/delete\", handler.${capitalizedFileName}Delete)
		${fileName}Router.Get(\"/get\", handler.${capitalizedFileName}Get)
		${fileName}Router.Get(\"/form\", handler.${capitalizedFileName}Form)
	}
}"
# router 结束

# service 开始
serviceContent="package $(basename $service)

import (
    \"$modeName/internal/model\"
    \"$modeName/pkg/db\"
    \"$modeName/pkg/tool\"
	\"$modeName/pkg/erro\"
)

// ${capitalizedFileName}Add 添加
func ${capitalizedFileName}Add(req model.${capitalizedFileName}Add) erro.Error {
    dbBegin := db.Gorm
	//
	// 请求参数处理后添加到数据库
	// 赋值操作
    param := model.${capitalizedFileName}{}
	err := dbBegin.Create(&param).Error
	if err != nil {
		return erro.New(err, \"操作失败\", nil)
	}
	return erro.Ok(nil)
}

// ${capitalizedFileName}Edit 编辑
func ${capitalizedFileName}Edit(req model.${capitalizedFileName}Edit) erro.Error {
    session := db.Gorm

	param := model.${capitalizedFileName}{}

	// 请求参数处理后添加到数据库
	// 赋值操作
    err := session.Where(\"id = ?\", req.Id).Updates(&param).Error
    if err != nil {
        return erro.New(err, \"操作失败\", nil)
    }
    return erro.Ok(nil)
}

// ${capitalizedFileName}Delete 删除
func ${capitalizedFileName}Delete(req model.${capitalizedFileName}Delete) erro.Error {
    session := db.Gorm

	if len(req.IdStr) > 0 {
	    err := session.Where(\"id in ?\", req.IdStr).Delete(&model.${capitalizedFileName}{}).Error
		if err != nil {
		return erro.New(err, \"操作失败\", nil)
		}
	}
    return erro.Ok(nil)
}


// ${capitalizedFileName}Get 查询
func ${capitalizedFileName}Get(req model.${capitalizedFileName}Get) erro.Error {
    session := db.Gorm

	param := model.${capitalizedFileName}{}

	// 赋值操作
    result, err := tool.Page(req.Page, req.Limit, session, &param)
    if err != nil {
        return erro.New(err, \"操作失败\", nil)
    }
    return erro.Ok(result)
}


// ${capitalizedFileName}Form 查询
func ${capitalizedFileName}Form(req model.${capitalizedFileName}Form) erro.Error {
    session := db.Gorm

	param := model.${capitalizedFileName}{}
	// 赋值操作
	err := session.Take(&param, req.Id).Error
	if err != nil {
		return erro.New(err, \"操作失败\", nil)
	}
    return erro.Ok(nil)
}
"
# service 结束

# 在目录中创建一个main.go文件并写入内容
echo "$handlerContent" > "$handler/$fileName.go"
echo "$modelContent"   > "$model/$fileName.go"
echo "$routerContent"  > "$router/$fileName.go"
echo "$serviceContent" > "$service/$fileName.go"