<?php

namespace App\Filament\Admin\Resources\AccountResource\Widgets;

use App\Domain\Account\Models\Account;
use App\Domain\Account\Models\Transaction;
use App\Domain\Account\Models\Turnover;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class AccountStatsOverview extends BaseWidget
{
    public ?Model $record = null;

    protected static ?string $pollingInterval = null;

    protected function getStats(): array
    {
        if (! $this->record) {
            // Dashboard stats for all accounts - use cache to avoid skeleton screens
            $cacheKey = 'admin_account_stats_overview';
            $stats = Cache::remember($cacheKey, now()->addMinutes(5), function () {
                return $this->getAccountStats();
            });

            return $this->buildStats($stats);
        }

        // Individual account stats
        return $this->getIndividualStats($this->record);
    }

    /**
     * Get account statistics using optimized queries
     */
    private function getAccountStats(): array
    {
        try {
            $accountStats = Account::selectRaw('
                COUNT(*) as total_accounts,
                SUM(CASE WHEN frozen = 0 THEN 1 ELSE 0 END) as active_accounts,
                SUM(CASE WHEN frozen = 1 THEN 1 ELSE 0 END) as frozen_accounts,
                COALESCE(SUM(balance), 0) as total_balance
            ')->first();

            return [
                'total_accounts' => $accountStats->total_accounts ?? 0,
                'active_accounts' => $accountStats->active_accounts ?? 0,
                'frozen_accounts' => $accountStats->frozen_accounts ?? 0,
                'total_balance' => $accountStats->total_balance ?? 0,
            ];
        } catch (\Exception $e) {
            \Log::error('Error fetching account stats: ' . $e->getMessage());

            return [
                'total_accounts' => 0,
                'active_accounts' => 0,
                'frozen_accounts' => 0,
                'total_balance' => 0,
            ];
        }
    }

    /**
     * Build stats array from account data
     */
    private function buildStats(array $stats): array
    {
        $totalAccounts = $stats['total_accounts'] ?? 0;
        $activeAccounts = $stats['active_accounts'] ?? 0;
        $frozenAccounts = $stats['frozen_accounts'] ?? 0;
        $totalBalance = $stats['total_balance'] ?? 0;

        return [
            Stat::make('Total Accounts', number_format($totalAccounts))
                ->description($activeAccounts . ' active, ' . $frozenAccounts . ' frozen')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('success'),
            Stat::make('Total Balance', '$' . number_format($totalBalance / 100, 2))
                ->description('Across all accounts')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('primary'),
            Stat::make('Average Balance', '$' . number_format($totalAccounts > 0 ? ($totalBalance / 100) / $totalAccounts : 0, 2))
                ->description('Per account')
                ->descriptionIcon('heroicon-m-calculator')
                ->color('info'),
            Stat::make('Frozen Accounts', $frozenAccounts)
                ->description(number_format($totalAccounts > 0 ? ($frozenAccounts / $totalAccounts) * 100 : 0, 1) . '% of total')
                ->descriptionIcon($frozenAccounts > 0 ? 'heroicon-m-exclamation-triangle' : 'heroicon-m-check-circle')
                ->color($frozenAccounts > 0 ? 'danger' : 'success'),
        ];
    }

    /**
     * Get individual account statistics
     */
    private function getIndividualStats(Model $account): array
    {
        try {
            $cacheKey = "account_stats_{$account->uuid}";

            return Cache::remember($cacheKey, now()->addMinutes(5), function () use ($account) {
                $lastTransaction = Transaction::where('account_uuid', $account->uuid)
                    ->latest()
                    ->first();

                $monthlyTurnover = Turnover::where('account_uuid', $account->uuid)
                    ->whereMonth('created_at', now()->month)
                    ->whereYear('created_at', now()->year)
                    ->first();

                $totalTransactions = Transaction::where('account_uuid', $account->uuid)->count();

                return [
                    Stat::make('Current Balance', '$' . number_format($account->balance / 100, 2))
                        ->description($account->frozen ? 'Account Frozen' : 'Account Active')
                        ->descriptionIcon($account->frozen ? 'heroicon-m-lock-closed' : 'heroicon-m-lock-open')
                        ->color($account->frozen ? 'danger' : 'success'),
                    Stat::make('Total Transactions', number_format($totalTransactions))
                        ->description($lastTransaction ? 'Last: ' . \Carbon\Carbon::parse($lastTransaction->created_at)->diffForHumans() : 'No transactions')
                        ->descriptionIcon('heroicon-m-arrow-path')
                        ->color('info'),
                    Stat::make('Monthly Credit', '$' . number_format(($monthlyTurnover?->credit ?? 0) / 100, 2))
                        ->description('This month')
                        ->descriptionIcon('heroicon-m-arrow-down-tray')
                        ->color('success'),
                    Stat::make('Monthly Debit', '$' . number_format(($monthlyTurnover?->debit ?? 0) / 100, 2))
                        ->description('This month')
                        ->descriptionIcon('heroicon-m-arrow-up-tray')
                        ->color('warning'),
                ];
            });
        } catch (\Exception $e) {
            \Log::error('Error fetching individual account stats: ' . $e->getMessage());

            return [
                Stat::make('Error', 'Unable to load stats')
                    ->color('danger'),
            ];
        }
    }
}
