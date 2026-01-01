// Sample API Server Implementation
// Path: cmd/api-server/main.go
// This demonstrates best practices for building the API server

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/trace"
	"go.uber.org/zap"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	// Internal imports (adjust based on your module path)
	"github.com/finaegis/finaegis-go/internal/application/command"
	"github.com/finaegis/finaegis-go/internal/application/query"
	"github.com/finaegis/finaegis-go/internal/infrastructure/ledger/blnk"
	"github.com/finaegis/finaegis-go/internal/interfaces/rest/handler"
	"github.com/finaegis/finaegis-go/internal/interfaces/rest/middleware"
	"github.com/finaegis/finaegis-go/internal/shared/cqrs/bus"
	"github.com/finaegis/finaegis-go/internal/shared/logger"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

type App struct {
	config      *Config
	logger      *zap.Logger
	db          *gorm.DB
	commandBus  *bus.CommandBus
	queryBus    *bus.QueryBus
	httpServer  *http.Server
}

type Config struct {
	Server struct {
		Host         string
		Port         int
		Mode         string
		ReadTimeout  time.Duration
		WriteTimeout time.Duration
	}
	Database struct {
		URL            string
		MaxConnections int
	}
	Observability struct {
		Logging struct {
			Level  string
			Format string
		}
		Tracing struct {
			Enabled     bool
			Endpoint    string
			ServiceName string
		}
	}
	Ledger struct {
		Provider string
	}
}

func main() {
	// Initialize application
	app, err := NewApp()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize application: %v\n", err)
		os.Exit(1)
	}
	defer app.Shutdown()

	// Run application
	if err := app.Run(); err != nil {
		app.logger.Fatal("Application failed", zap.Error(err))
	}
}

func NewApp() (*App, error) {
	// Load configuration
	config, err := loadConfig()
	if err != nil {
		return nil, fmt.Errorf("load config: %w", err)
	}

	// Initialize logger
	log, err := initLogger(config)
	if err != nil {
		return nil, fmt.Errorf("init logger: %w", err)
	}

	log.Info("Starting FinAegis API Server",
		zap.String("version", version),
		zap.String("commit", commit),
		zap.String("date", date),
	)

	// Initialize tracing
	if config.Observability.Tracing.Enabled {
		if err := initTracing(config); err != nil {
			log.Warn("Failed to initialize tracing", zap.Error(err))
		} else {
			log.Info("Tracing initialized", zap.String("endpoint", config.Observability.Tracing.Endpoint))
		}
	}

	// Initialize database
	db, err := initDatabase(config, log)
	if err != nil {
		return nil, fmt.Errorf("init database: %w", err)
	}

	// Initialize CQRS buses
	commandBus := bus.NewCommandBus()
	queryBus := bus.NewQueryBus()

	// Register handlers
	if err := registerHandlers(commandBus, queryBus, db, log); err != nil {
		return nil, fmt.Errorf("register handlers: %w", err)
	}

	app := &App{
		config:     config,
		logger:     log,
		db:         db,
		commandBus: commandBus,
		queryBus:   queryBus,
	}

	return app, nil
}

func (app *App) Run() error {
	// Setup Gin router
	router := app.setupRouter()

	// Create HTTP server
	app.httpServer = &http.Server{
		Addr:         fmt.Sprintf("%s:%d", app.config.Server.Host, app.config.Server.Port),
		Handler:      router,
		ReadTimeout:  app.config.Server.ReadTimeout,
		WriteTimeout: app.config.Server.WriteTimeout,
	}

	// Start server in goroutine
	go func() {
		app.logger.Info("Starting HTTP server",
			zap.String("addr", app.httpServer.Addr),
			zap.String("mode", app.config.Server.Mode),
		)

		if err := app.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			app.logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	app.logger.Info("Shutting down server...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := app.httpServer.Shutdown(ctx); err != nil {
		return fmt.Errorf("server forced to shutdown: %w", err)
	}

	app.logger.Info("Server exited gracefully")
	return nil
}

func (app *App) setupRouter() *gin.Engine {
	// Set Gin mode
	gin.SetMode(app.config.Server.Mode)

	router := gin.New()

	// Global middleware
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.Logger(app.logger))
	router.Use(middleware.CORS())
	router.Use(middleware.Metrics())

	// Health checks
	router.GET("/health", handler.HealthCheck(app.db))
	router.GET("/ready", handler.ReadinessCheck(app.db))

	// Metrics endpoint
	router.GET("/metrics", handler.Metrics())

	// API version 1
	v1 := router.Group("/api/v1")
	{
		// Multi-tenancy middleware
		v1.Use(middleware.TenantResolver())

		// Authentication middleware
		v1.Use(middleware.AuthMiddleware())

		// Account endpoints
		accounts := v1.Group("/accounts")
		{
			accountHandler := handler.NewAccountHandler(app.commandBus, app.queryBus, app.logger)
			accounts.POST("", accountHandler.CreateAccount)
			accounts.GET("/:id", accountHandler.GetAccount)
			accounts.GET("/:id/balance", accountHandler.GetBalance)
			accounts.POST("/:id/deposit", accountHandler.Deposit)
			accounts.POST("/:id/withdraw", accountHandler.Withdraw)
		}

		// Transfer endpoints
		transfers := v1.Group("/transfers")
		{
			transferHandler := handler.NewTransferHandler(app.commandBus, app.queryBus, app.logger)
			transfers.POST("", transferHandler.CreateTransfer)
			transfers.GET("/:id", transferHandler.GetTransfer)
			transfers.GET("", transferHandler.ListTransfers)
		}

		// Payment endpoints
		payments := v1.Group("/payments")
		{
			paymentHandler := handler.NewPaymentHandler(app.commandBus, app.queryBus, app.logger)
			payments.POST("/deposit", paymentHandler.ProcessDeposit)
			payments.POST("/withdraw", paymentHandler.ProcessWithdrawal)
			payments.GET("/:id", paymentHandler.GetPayment)
		}

		// Exchange endpoints
		exchange := v1.Group("/exchange")
		{
			exchangeHandler := handler.NewExchangeHandler(app.commandBus, app.queryBus, app.logger)

			// Orders
			exchange.POST("/orders", exchangeHandler.PlaceOrder)
			exchange.GET("/orders/:id", exchangeHandler.GetOrder)
			exchange.DELETE("/orders/:id", exchangeHandler.CancelOrder)

			// Liquidity pools
			exchange.POST("/pools", exchangeHandler.CreatePool)
			exchange.POST("/pools/:id/liquidity", exchangeHandler.AddLiquidity)
			exchange.POST("/pools/:id/swap", exchangeHandler.ExecuteSwap)
			exchange.GET("/pools/:id", exchangeHandler.GetPool)
		}

		// Wallet endpoints
		wallets := v1.Group("/wallets")
		{
			walletHandler := handler.NewWalletHandler(app.commandBus, app.queryBus, app.logger)
			wallets.POST("", walletHandler.CreateWallet)
			wallets.GET("/:id", walletHandler.GetWallet)
			wallets.POST("/:id/deposit", walletHandler.DepositCrypto)
			wallets.POST("/:id/withdraw", walletHandler.WithdrawCrypto)
		}

		// Compliance endpoints
		compliance := v1.Group("/compliance")
		{
			complianceHandler := handler.NewComplianceHandler(app.commandBus, app.queryBus, app.logger)
			compliance.POST("/kyc", complianceHandler.InitiateKYC)
			compliance.GET("/kyc/:id", complianceHandler.GetKYCStatus)
			compliance.POST("/screening", complianceHandler.ScreenTransaction)
		}
	}

	// Admin API (separate authentication)
	admin := router.Group("/admin")
	{
		admin.Use(middleware.AdminAuth())

		admin.GET("/stats", handler.GetSystemStats())
		admin.POST("/tenants", handler.CreateTenant())
		admin.GET("/tenants", handler.ListTenants())
	}

	// Webhook endpoints (validate signatures)
	webhooks := router.Group("/webhooks")
	{
		webhooks.POST("/stripe", handler.StripeWebhook())
		webhooks.POST("/moov", handler.MoovWebhook())
		webhooks.POST("/blockchain", handler.BlockchainWebhook())
	}

	return router
}

func (app *App) Shutdown() {
	app.logger.Info("Cleaning up resources...")

	// Close database connection
	if app.db != nil {
		sqlDB, err := app.db.DB()
		if err == nil {
			sqlDB.Close()
		}
	}

	// Flush logger
	app.logger.Sync()
}

// Configuration loading
func loadConfig() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./configs/dev")
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")

	// Environment variable overrides
	viper.AutomaticEnv()

	// Defaults
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.mode", "debug")
	viper.SetDefault("server.read_timeout", "30s")
	viper.SetDefault("server.write_timeout", "30s")

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, err
		}
		// Config file not found; using defaults
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	return &config, nil
}

// Logger initialization
func initLogger(config *Config) (*zap.Logger, error) {
	var zapConfig zap.Config

	if config.Observability.Logging.Format == "json" {
		zapConfig = zap.NewProductionConfig()
	} else {
		zapConfig = zap.NewDevelopmentConfig()
	}

	// Set log level
	level, err := zap.ParseAtomicLevel(config.Observability.Logging.Level)
	if err != nil {
		level = zap.NewAtomicLevelAt(zap.InfoLevel)
	}
	zapConfig.Level = level

	return zapConfig.Build()
}

// Tracing initialization
func initTracing(config *Config) error {
	ctx := context.Background()

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(config.Observability.Tracing.Endpoint),
		otlptracehttp.WithInsecure(), // Use WithTLSCredentials in production
	)
	if err != nil {
		return err
	}

	tp := trace.NewTracerProvider(
		trace.WithBatcher(exporter),
		trace.WithSampler(trace.AlwaysSample()),
	)

	otel.SetTracerProvider(tp)

	return nil
}

// Database initialization
func initDatabase(config *Config, log *zap.Logger) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(config.Database.URL), &gorm.Config{
		Logger: logger.NewGormLogger(log),
	})
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("get sql.DB: %w", err)
	}

	// Connection pool settings
	sqlDB.SetMaxOpenConns(config.Database.MaxConnections)
	sqlDB.SetMaxIdleConns(config.Database.MaxConnections / 4)
	sqlDB.SetConnMaxLifetime(time.Hour)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := sqlDB.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping database: %w", err)
	}

	log.Info("Database connected", zap.String("url", config.Database.URL))

	return db, nil
}

// Register command and query handlers
func registerHandlers(
	commandBus *bus.CommandBus,
	queryBus *bus.QueryBus,
	db *gorm.DB,
	log *zap.Logger,
) error {
	// Initialize ledger service (pluggable)
	ledgerService := blnk.NewBlnkLedger() // Or use internal/formance based on config

	// Account command handlers
	commandBus.Register(
		&command.CreateAccountCommand{},
		command.NewCreateAccountHandler(ledgerService, log),
	)
	commandBus.Register(
		&command.DepositCommand{},
		command.NewDepositHandler(ledgerService, log),
	)
	commandBus.Register(
		&command.WithdrawCommand{},
		command.NewWithdrawHandler(ledgerService, log),
	)
	commandBus.Register(
		&command.TransferCommand{},
		command.NewTransferHandler(ledgerService, log),
	)

	// Account query handlers
	queryBus.Register(
		&query.GetAccountQuery{},
		query.NewGetAccountHandler(db, log),
	)
	queryBus.Register(
		&query.GetBalanceQuery{},
		query.NewGetBalanceHandler(ledgerService, log),
	)

	// TODO: Register handlers for other domains

	return nil
}
