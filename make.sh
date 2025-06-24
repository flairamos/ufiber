#!/bin/bash

# 确定操作系统类型
echo "正在识别系统类型..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    os="Mac"
    echo "已检测到系统：Mac OS"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    os="Windows"
    echo "已检测到系统：Windows"
else
    echo "错误：不支持的操作系统类型。"
    exit 1
fi

# 获取用户输入的文件夹名称
read -p "请输入要创建的文件夹名称：" folder_name

# 依据系统类型创建文件夹
echo "正在创建文件夹..."
if [[ "$os" == "Windows" ]]; then
    mkdir -p "$folder_name"
else
    mkdir -p "$folder_name"
fi

# 检查文件夹是否成功创建
if [[ ! -d "$folder_name" ]]; then
    echo "错误：文件夹创建失败。"
    exit 1
fi
echo "文件夹创建成功：$folder_name"

# 进入新创建的文件夹
cd "$folder_name" || exit

# 执行go mod init命令
echo "正在初始化Go模块..."
go mod init "$folder_name"

# 检查命令执行状态
if [[ $? -ne 0 ]]; then
    echo "错误：Go模块初始化失败。"
    exit 1
fi
echo "Go模块初始化成功：$folder_name"

# 创建main.go文件
echo "正在创建main.go文件..."
cat > main.go << EOF
package main

import (
	"fmt"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"$folder_name/config"
	"$folder_name/pkg/db"
	minioutil "$folder_name/pkg/minio_util"
	redisutil "$folder_name/pkg/redis_util"
	"$folder_name/route"
)

func main() {
	app := fiber.New(fiber.Config{
		BodyLimit:         500 * 1024 * 1024, // this is the default limit of 4MB
		StreamRequestBody: true,
		EnablePrintRoutes: true,
	})
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "*",
	}))
	config.Init()
	db.Init()
	minioutil.Init()
	redisutil.Init()
	// 其他初始化逻辑

	route.Init(app)
	err := app.Listen(fmt.Sprintf(":%d", config.Config.Server.Port))
	if err != nil {
		panic(err)
	}
}
EOF
echo "main.go文件创建成功"

# 创建config目录
echo "正在创建config目录..."
mkdir -p config
echo "config目录创建成功"

# 创建config/config.go文件
echo "正在创建config/config.go文件..."
cat > config/config.go << EOF
package config

import (
    "flag"
    "fmt"
    "gopkg.in/yaml.v3"
    "log"
    "os"
    "runtime"
)

type server struct {
    Port   int    \`yaml:"port"\`
    ImgUrl string \`yaml:"imgUrl"\`
}

type database struct {
    Driver string \`yaml:"driver"\`
    User   string \`yaml:"user"\`
    Passwd string \`yaml:"passwd"\`
    Addr   string \`yaml:"addr"\`
    Port   int    \`yaml:"port"\`
    DBName string \`yaml:"dbName"\`
    Zone   string \`yaml:"zone"\`
}

type jwt struct {
    Key string \`yaml:"key"\`
}

type minio struct {
    Endpoint     string \`yaml:"endpoint"\`
    AccessKey    string \`yaml:"accessKey"\`
    SecretAccess string \`yaml:"secretKey"\`
    UseSSL       bool   \`yaml:"ssl"\`
    Bucket       string \`yaml:"bucket"\`
}

type redis struct {
    Host     string \`yaml:"host"\`
    Password string \`yaml:"password"\`
    Database string \`yaml:"database"\`
}

type wechat struct {
    AppId     string \`yaml:"appId"\`
    AppSecret string \`yaml:"appSecret"\`
}

type variable struct {
    FilePath string
    Server   server
    Database database
    Jwt      jwt
    Minio    minio
    Redis    redis
    Wechat   wechat
}

var (
    Config variable
)

func Init() {
    dir, err := os.Getwd()
    if err != nil {
        log.Println("获取根目录失败:", err)
        return
    }
    var run string
    if runtime.GOOS == "windows" {
        run = dir + "\\config.yaml"
        if s := flag.String("run", "", "runtime environment"); *s != "" {
            run = fmt.Sprintf("%s\\config_%s.yaml", dir, *s)
        }
    } else {
        run = dir + "/config.yaml"
        if s := flag.String("run", "", "runtime environment"); *s != "" {
            run = fmt.Sprintf("%s/config_%s.yaml", dir, *s)
        }
    }
    Config.FilePath = dir
    file, err := os.ReadFile(run)
    if err != nil {
        log.Println("读取配置文件失败或配置文件不存在:", err)
        return
    }
    err = yaml.Unmarshal(file, &Config)
    if err != nil {
        log.Println("解析配置文件失败，请检查格式是否正确:", err)
        return
    }
    log.Println("配置文件加载成功")
}
EOF
echo "config/config.go文件创建成功"

# 创建config.yaml文件
echo "正在创建config.yaml文件..."
cat > config.yaml << EOF
server:
    port: 8081
    imgUrl: http://127.0.0.1:8081
    run: dev

database:
    driver: postgres
    user: postgres
    passwd: test
    addr: 127.0.0.1
    port: 5432
    dbName: test
    zone: Asia/Shanghai

jwt:
    key: test

minio:
    endpoint: 127.0.0.1:9000
    accessKey: minioadmin
    secretKey: minioadmin
    ssl: false
    bucket: local

redis:
    host: 127.0.0.1:6379
    password: root
    database: 8

wechat:
    appId: test
    appSecret: test
EOF
echo "config.yaml文件创建成功"

# 创建pkg/db目录
echo "正在创建pkg/db目录..."
mkdir -p pkg/db
echo "pkg/db目录创建成功"

# 创建pkg/db/db.go文件
echo "正在创建pkg/db/db.go文件..."
cat > pkg/db/db.go << EOF
package db

import (
    "fmt"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/schema"
    "$folder_name/config"
)

var Gorm *gorm.DB

func Init() {
    database := config.Config.Database
    option := &gorm.Config{
        // 配置查询时表非复数形式
        NamingStrategy: schema.NamingStrategy{
            SingularTable: true,
        },
        //Logger: logger.New(log_util.Logger, logger.Config{
        //  Colorful: true,
        //}),
    }
    var dialector gorm.Dialector
    if database.Driver == "postgres" {
        dialector = postgres.Open(fmt.Sprintf(
            "user=%s password=%s host=%s port=%d dbname=%s TimeZone=%s",
            database.User,
            database.Passwd,
            database.Addr,
            database.Port,
            database.DBName,
            database.Zone,
        ))
    } else {
        panic("数据库驱动不支持")
    }
    // 连接数据库
    db, err := gorm.Open(dialector, option)
    if err != nil {
        panic(fmt.Sprintf("连接数据库失败: %v", err))
    }
    Gorm = db
    fmt.Println("数据库连接成功")
}
EOF
echo "pkg/db/db.go文件创建成功"



# 创建pkg/jwt_util目录
echo "正在创建pkg/jwt_util目录目录..."
mkdir -p pkg/jwt_util
echo "pkg/jwt_util目录创建成功"

# 创建pkg/db/db.go文件
echo "正在创建pkg/jwt_util/jwt.go文件..."
cat > pkg/jwt_util/jwt.go << EOF
package jwt_util

import (
    "errors"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"$folder_name/config"
	"strings"
	"time"
)

func GenerateToken(userId int32, phone string) (string, error) {
	// 创建一个JWT对象
	jwt := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userId,
		"phone":   phone,
		// "exp":     time.Now().Add(time.Hour * 24).Unix(), // 设置过期时间为24小时
	})
	return jwt.SignedString([]byte(config.Config.Jwt.Key))
}

func GenerateTokenWithExp(userId string, phone string) (string, error) {
	// 创建一个JWT对象
	jwt := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userId,
		"phone":   phone,
		"exp":     time.Now().Add(time.Hour * 12).Unix(), // 设置过期时间为24小时
	})
	return jwt.SignedString([]byte(config.Config.Jwt.Key))
}

func ParseJwtWithClaims(key any, jwtStr string, options ...jwt.ParserOption) (jwt.MapClaims, error) {
	mc := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(jwtStr, mc, func(token *jwt.Token) (interface{}, error) {
		return key, nil
	}, options...)
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, errors.New("invalid token")
	}
	return token.Claims.(jwt.MapClaims), nil
}

func ParseJwtWithClaimsWithExp(key any, jwtStr string, options ...jwt.ParserOption) (jwt.MapClaims, error) {
	mc := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(jwtStr, mc, func(token *jwt.Token) (interface{}, error) {
		return key, nil
	}, options...)
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, errors.New("invalid token")
	}
	mc = token.Claims.(jwt.MapClaims)
	if mc["exp"] == nil {
		return nil, errors.New("expired token")
	}
	if mc["exp"].(float64) < float64(time.Now().Unix()) {
		return nil, errors.New("expired token")
	}
	return mc, nil
}

func ParseJwtWithCtx(c *fiber.Ctx) (jwt.MapClaims, error) {
	auth := c.Get("Authorization")
	token := strings.Split(auth, "Bearer")
	if auth == "" {
		return nil, errors.New("invalid auth")
	}
	if len(token) < 2 {
		return nil, errors.New("invalid token")
	}
	if token[1] == "" {
		return nil, errors.New("invalid token")
	}
	return ParseJwtWithClaims([]byte(config.Config.Jwt.Key), strings.TrimSpace(token[1]))
}

func ParseJwtWithCtxAndExp(c *fiber.Ctx) (jwt.MapClaims, error) {
	auth := c.Get("Authorization")
	token := strings.Split(auth, "Bearer")
	if auth == "" {
		return nil, errors.New("invalid auth")
	}
	if len(token) < 2 {
		return nil, errors.New("invalid token")
	}
	if token[1] == "" {
		return nil, errors.New("invalid token")
	}
	return ParseJwtWithClaimsWithExp([]byte(config.Config.Jwt.Key), strings.TrimSpace(token[1]))
}
EOF
echo "pkg/jwt_util/jwt.go文件创建成功"


echo "正在创建pkg/jwt_util/auth.go文件..."
cat > pkg/jwt_util/auth.go << EOF 

package jwt_util

import (
	"github.com/gofiber/fiber/v2"
)

func Auth(c *fiber.Ctx) error {
	ctx, err := ParseJwtWithCtx(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"code": 500,
			"msg":  "token错误",
		})
	}
	id, ok := ctx["user_id"]
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"code": 500,
			"msg":  "token无效",
		})
	}
	// 判断用户是否存在
	_ = id
	return c.Next()
}
EOF
echo "pkg/jwt_util/auth.go文件创建成功"


echo "正在创建pkg/minio_util目录..."
mkdir -p pkg/minio_util
echo "pkg/minio_util目录创建成功"


echo "正在创建pkg/minio_util/client.go文件..."
cat > pkg/minio_util/client.go << EOF
package minioutil

import (
	"fmt"
	"github.com/minio/minio-go"
	"$folder_name/config"
	"log"
)

var (
	Client *minio.Client
)

func Init() {
	conf := config.Config.Minio
	client, err := minio.New(conf.Endpoint, conf.AccessKey, conf.SecretAccess, conf.UseSSL)
	if err != nil {
		log.Println("minio client create err: ", err)
		panic(err)
	}
	// 判断认证信息是否有误
	_, err = client.ListBuckets()
	if err != nil {
		log.Println("minio client list buckets err: ", err)
		panic(err)
	}
	Client = client
	fmt.Println("minio client created")
	return
}

func MakeBucket(bucket string) error {
	exists, err := Client.BucketExists(bucket)
	if err != nil {
		log.Println("桶验证错误", err.Error())
		return err
	}
	if !exists {
		err = Client.MakeBucket(bucket, "us-east-1")
		if err != nil {
			return err
		}
	}
	return nil
}
EOF
echo "pkg/minio_util/client.go文件创建成功"


echo "正在创建pkg/minio_util/upload.go文件..."
cat > pkg/minio_util/upload.go << EOF
package minioutil

import (
	"bytes"
	"io"
	"log"
	"$folder_name/config"
	"$folder_name/pkg/tool"

	"github.com/minio/minio-go"
)

// filetype是文件的后缀
func Upload(by []byte, filetype string, buckets ...string) (string, error) {
	filename := tool.Uuid() + "." + filetype
	var bucket string
	if len(bucket) == 0 {
		bucket = config.Config.Minio.Bucket
	} else {
		bucket = buckets[0]
	}
	_, err := Client.PutObject(bucket, filename, bytes.NewReader(by), int64(len(by)), minio.PutObjectOptions{})
	if err != nil {
		log.Println("minio上传文件失败", err.Error())
		return "", err
	}
	return filename, nil
}

func Download(filename string, buckets ...string) ([]byte, error) {
	var bucket string
	if len(bucket) == 0 {
		bucket = config.Config.Minio.Bucket
	} else {
		bucket = buckets[0]
	}
	obj, err := Client.GetObject(bucket, filename, minio.GetObjectOptions{})
	if err != nil {
		log.Println("minio获取文件失败", err.Error())
		return nil, err
	}
	by, err := io.ReadAll(obj)
	if err != nil {
		log.Println("读取文件流失败", err.Error())
	}
	return by, nil
}

func Preview(filename string, buckets ...string) ([]byte, string, error) {
	var bucket string
	if len(bucket) == 0 {
		bucket = config.Config.Minio.Bucket
	} else {
		bucket = buckets[0]
	}
	obj, err := Client.GetObject(bucket, filename, minio.GetObjectOptions{})
	if err != nil {
		log.Println("minio获取文件失败", err.Error())
		return nil, "", err
	}
	by, err := io.ReadAll(obj)
	if err != nil {
		log.Println("读取文件流失败", err.Error())
		return nil, "", err
	}
	info, err := obj.Stat()
	if err != nil {
		log.Println("获取文件信息失败", err.Error())
		return by, "application/octet-stream", nil
	}
	return by, info.ContentType, nil
}
EOF
echo "pkg/minio_util/upload.go文件上传成功"



echo "正在创建pkg/redis_util文件夹..."
mkdir -p pkg/redis_util
echo "pkg/redis_util文件夹创建成功"


echo "正在创建pkg/redis_util/redis.go文件"
cat > pkg/redis_util/redis.go << EOF
package redisutil

import (
	"fmt"
	"$folder_name/config"

	"github.com/gomodule/redigo/redis"
)

var Client *redis.Conn

func Init() {
	conf := config.Config.Redis
	conn, err := redis.Dial("tcp", conf.Host)
	if err != nil {
		// panic(errors.New("conn redis failed"))
		fmt.Println("conn redis failed")
		return
	}
	if conf.Password != "" {
		_, err = conn.Do("auth", conf.Password)
		if err != nil {
			// panic(errors.New("redis auth failed"))
			fmt.Println("redis auth failed")
		}
	}
	// 选择第一个数据库
	_, err = conn.Do("SELECT", conf.Database)
	if err != nil {
		// panic(errors.New("redis select database failed"))
		fmt.Println("redis select database failed")
	}
	Client = &conn
	fmt.Println("conn redis success")
}
EOF
echo "pkg/redis_util/redis.go创建成功"



echo "正在创建pkg/respond文件夹..."
mkdir -p pkg/respond
echo "pkg/respond文件夹创建成功"


echo "正在创建pkg/respond/respond.go文件..."
cat > pkg/respond/respond.go << EOF
package respond

import (
	"github.com/gofiber/fiber/v2"
	"$folder_name/pkg/erro"
)

func Fail(c *fiber.Ctx, msg string, err error) error {
	return c.JSON(fiber.Map{
		"code":  "500",
		"msg":   msg,
		"error": err.Error(),
	})
}

func Ok(c *fiber.Ctx, data any, msg ...string) error {
	var message string
	if len(msg) == 0 {
		message = "操作成功"
	} else {
		message = ""
		for _, s := range msg {
			message += s
		}
	}
	return c.JSON(fiber.Map{
		"code": "200",
		"msg":  message,
		"data": data,
	})
}
func Do(c *fiber.Ctx, err erro.Error) error {
	if err.Err != nil {
		return c.JSON(fiber.Map{
			"code":  "500",
			"msg":   err.Msg,
			"error": err.Err.Error(),
		})
	}
	return c.JSON(fiber.Map{
		"code": "200",
		"msg":  err.Msg,
		"data": err.Data,
	})
}
EOF
echo "创建pkg/respond/respond.go成功"



echo "正在创建pkg/tool文件..."
mkdir -p pkg/tool
echo "pkg/tool文件创建成功"


echo "正在创建pkg/tool/convert.go文件..."
cat > pkg/tool/convert.go << EOF
package tool

import (
	"strconv"
	"strings"
	"time"
)

func StrInt(s string) int {
	if s == "" {
		return 0
	}
	i, err := strconv.Atoi(s)
	if err != nil {
		return 0
	}
	return i
}
func StrInt32(s string) int32 {
	if s == "" {
		return 0
	}
	si, err := strconv.ParseInt(s, 10, 32)
	if err != nil {
		return 0
	}
	return int32(si)
}

func StrInt64(s string) int64 {
	if s == "" {
		return 0
	}
	si, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0
	}
	return si
}

func StrFloat64(s string) float64 {
	if s == "" {
		return 0
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return f
}

func IntStr(number int64) string {
	if number == 0 {
		return ""
	}
	return strconv.FormatInt(number, 10)
}

func FloatStr(number float64, bit int) string {
	if number == 0 {
		return ""
	}
	return strconv.FormatFloat(10.111000000000, 'f', bit, 64)
}

func StrToDate(t string) time.Time {
	layout := "2006-01-02"
	if t == "" {
		return time.Time{}
	}
	parse, err := time.Parse(layout, t)
	if err != nil {
		return time.Time{}
	}
	return parse
}

func StrToTime(t string) time.Time {
	layout := "2006-01-02 15:04:05"
	parse, err := time.Parse(layout, t)
	if err != nil {
		return time.Time{}
	}
	return parse
}

func TimeToStr(t time.Time) string {
	layout := "2006-01-02 15:04:05"
	return t.Format(layout)
}

func DateToStr(t time.Time) string {
	layout := "2006-01-02"
	format := t.Format(layout)
	split := strings.Split(format, " ")
	if split[0] == "0001-01-01" {
		return ""
	}
	return split[0]
}

func StrBool(s any) bool {
	if s == nil {
		return false
	} else {
		switch s.(type) {
		case bool:
			b := s.(bool)
			return b
		case string:
			s2 := s.(string)
			if s2 == "" {
				return false
			} else {
				return true
			}
		default:
			return false
		}
	}
}
EOF
echo "pkg/tool/convert.go文件创建成功"


echo "正在创建pkg/tool/page.go文件..."
cat > pkg/tool/page.go << EOF
package tool

import (
	"fmt"
	"gorm.io/gorm"
	"math"
)

// 分页组件
// 除gorm其他类型均为非指针类型
// currentPage - 当前页  perPageSize - 每页大小 param 查询的结构体
// param传地址
func Page(currentPage, perPageSize int, db *gorm.DB, paramAddr any) (*dataPage, error) {
	var offset, limit int
	if currentPage <= 1 {
		currentPage = 1
	}
	if perPageSize <= 0 {
		perPageSize = 10
	}
	offset = (currentPage - 1) * perPageSize
	limit = perPageSize

	var count int64
	err := db.Count(&count).Offset(offset).Limit(limit).
		Find(paramAddr).Error
	if err != nil {
		return nil, err
	}

	pageNum := int(math.Ceil(float64(count) / float64(perPageSize)))
	result := dataPage{
		Data:        paramAddr,
		CurrentPage: currentPage,
		PerPageSize: perPageSize,
		Total:       count,
		PageNum:     pageNum,
		HasPrx: func() bool {
			if currentPage == 1 {
				return false
			}
			return true
		}(),
		HasNext: func() bool {
			if currentPage == pageNum {
				return false
			}
			return true
		}(),
	}
	return &result, nil
}

type dataPage struct {
	Data        any   \`json:"result"\`
	CurrentPage int   \`json:"current_page"\`
	PerPageSize int   \`json:"per_page_size"\`
	Total       int64 \`json:"total"\`
	PageNum     int   \`json:"page_num"\`
	HasPrx      bool  \`json:"has_prx"\`
	HasNext     bool  \`json:"has_next"\`
}

func HandlePage(currentPage, perPageSize int, db *gorm.DB, ptr any, sql string, args ...interface{}) (error, any) {
	var total int64
	err := db.Raw("select count(*) from ("+sql+")", args...).Scan(&total).Error
	if err != nil {
		return err, nil
	}
	var offset, limit int
	if currentPage <= 1 {
		currentPage = 1
	}
	if perPageSize <= 0 {
		perPageSize = 10
	}
	offset = (currentPage - 1) * perPageSize
	limit = perPageSize
	sql += fmt.Sprintf(" offset %d limit %d", offset, limit)
	err = db.Raw(sql, args...).Scan(ptr).Error
	if err != nil {
		return err, nil
	}
	pageNum := int(math.Ceil(float64(total) / float64(perPageSize)))
	result := dataPage{
		Data:        ptr,
		CurrentPage: currentPage,
		PerPageSize: perPageSize,
		Total:       total,
		PageNum:     pageNum,
		HasPrx: func() bool {
			if currentPage == 1 {
				return false
			}
			return true
		}(),
		HasNext: func() bool {
			if currentPage == pageNum {
				return false
			}
			return true
		}(),
	}
	return nil, result
}

func HandlePageOrder(currentPage, perPageSize int, db *gorm.DB, ptr any, sql string, order string, args ...interface{}) (error, any) {
	var total int64
	err := db.Raw("select count(*) from ("+sql+")", args...).Scan(&total).Error
	if err != nil {
		return err, nil
	}
	var offset, limit int
	if currentPage <= 1 {
		currentPage = 1
	}
	if perPageSize <= 0 {
		perPageSize = 10
	}
	offset = (currentPage - 1) * perPageSize
	limit = perPageSize
	sql += fmt.Sprintf(" order by %s offset %d limit %d ", order, offset, limit)
	err = db.Raw(sql, args...).Scan(ptr).Error
	if err != nil {
		return err, nil
	}
	pageNum := int(math.Ceil(float64(total) / float64(perPageSize)))
	result := dataPage{
		Data:        ptr,
		CurrentPage: currentPage,
		PerPageSize: perPageSize,
		Total:       total,
		PageNum:     pageNum,
		HasPrx: func() bool {
			if currentPage == 1 {
				return false
			}
			return true
		}(),
		HasNext: func() bool {
			if currentPage == pageNum {
				return false
			}
			return true
		}(),
	}
	return nil, result
}

func PageOrder(currentPage, perPageSize int, db *gorm.DB, paramAddr any, order string) (*dataPage, error) {
	var offset, limit int
	if currentPage <= 1 {
		currentPage = 1
	}
	if perPageSize <= 0 {
		perPageSize = 10
	}
	offset = (currentPage - 1) * perPageSize
	limit = perPageSize

	var count int64
	err := db.Count(&count).Offset(offset).Limit(limit).Order(order).
		Find(paramAddr).Error
	if err != nil {
		return nil, err
	}

	pageNum := int(math.Ceil(float64(count) / float64(perPageSize)))
	result := dataPage{
		Data:        paramAddr,
		CurrentPage: currentPage,
		PerPageSize: perPageSize,
		Total:       count,
		PageNum:     pageNum,
		HasPrx: func() bool {
			if currentPage == 1 {
				return false
			}
			return true
		}(),
		HasNext: func() bool {
			if currentPage == pageNum {
				return false
			}
			return true
		}(),
	}
	return &result, nil
}
EOF
echo "pkg/tool/page.go创建成功"


echo "正在创建pkg/tool/uuid.go..."
cat > pkg/tool/uuid.go << EOF
package tool

import (
	"github.com/google/uuid"
)

// UUID 生成没有破折号的 UUID
func Uuid() string {
	return uuid.NewString()
}
EOF


echo "正在创建路由route文件夹..."
mkdir route
echo "路由route文件夹创建成功"


cat > route/route.go << EOF
package route

import (
	"github.com/gofiber/fiber/v2"
	"$folder_name/pkg/jwt_util"
)

func Init(app *fiber.App) {
	private(app)
	app.Use(jwt_util.Auth)
	public(app)
}

func private(app *fiber.App) {
	route := app.Group("/api")
	{
		_ = route
	}
}

func public(app *fiber.App) {
	route := app.Group("/public")
	{
		_ = route
	}
}
EOF
echo "route/route.go创建成功"


echo "正在创建pkg/erro文件夹..."
mkdir -p pkg/erro
echo "已创建pkg/erro文件夹"


echo "正在创建pkg/erro/erro.go文件..."
cat > pkg/erro/erro.go << EOF
package erro

type Error struct {
	Err  error
	Msg  string
	Data any
}

func New(err error, msg string, data any) Error {
	return Error{
		Err:  err,
		Msg:  msg,
		Data: data,
	}
}

func Ok(data any) Error {
	return Error{
		Err:  nil,
		Msg:  "操作成功",
		Data: data,
	}
}

func Fail(err error, msg string) Error {
	return Error{
		Err:  err,
		Msg:  msg,
		Data: nil,
	}
}
EOF
echo "已创建pkg/erro/erro.go"

# 添加go mod tidy命令
# echo "正在下载依赖..."
# go get gopkg.in/yaml.v3
# go get gorm.io/gorm
# go get gorm.io/driver/postgres
# go mod tidy
# echo "依赖下载完成"

echo "操作全部完成！"    