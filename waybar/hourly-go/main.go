package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	defaultCurrency   = "R$"
	defaultHourlyRate = 0.0
)

type Entry struct {
	InDate  time.Time
	OutDate *time.Time
	Note    string
}

func (e Entry) IsOpen() bool { return e.OutDate == nil }

type Config struct {
	HourlyRate float64
	Currency   string
}

func (c Config) HasRate() bool { return c.HourlyRate > 0 }

type Metrics struct {
	TodayHours    float64
	MonthHours    float64
	TodayEarnings float64
	MonthEarnings float64
	Config        Config
	OpenEntry     *Entry
}

func readJSON(path string, dest any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, dest)
}

type rawConfig struct {
	HourlyRate float64 `json:"hourly_rate"`
	Currency   string  `json:"currency"`
}

func loadConfig(path string) Config {
	var raw rawConfig
	if err := readJSON(path, &raw); err != nil {
		return Config{HourlyRate: defaultHourlyRate, Currency: defaultCurrency}
	}
	if raw.Currency == "" {
		raw.Currency = defaultCurrency
	}
	return Config{HourlyRate: raw.HourlyRate, Currency: raw.Currency}
}

type rawEntry struct {
	In   string `json:"in"`
	Out  string `json:"out"`
	Note string `json:"note"`
}

type rawData struct {
	Entries []rawEntry `json:"entries"`
}

func loadEntries(path string) []Entry {
	var raw rawData
	if err := readJSON(path, &raw); err != nil {
		return nil
	}

	entries := make([]Entry, 0, len(raw.Entries))
	for _, re := range raw.Entries {
		entry, ok := parseEntry(re)
		if ok {
			entries = append(entries, entry)
		}
	}
	return entries
}

func parseEntry(re rawEntry) (Entry, bool) {
	inDate, err := time.Parse(time.RFC3339, re.In)
	if err != nil {
		return Entry{}, false
	}

	entry := Entry{InDate: inDate, Note: re.Note}

	if re.Out != "" {
		outDate, err := time.Parse(time.RFC3339, re.Out)
		if err == nil {
			entry.OutDate = &outDate
		}
	}

	return entry, true
}

func computeMetrics(entries []Entry, cfg Config, now time.Time) Metrics {
	todayHours := sumHours(entries, now, func(e Entry) bool { return isSameDay(e.InDate, now) })
	monthHours := sumHours(entries, now, func(e Entry) bool { return isSameMonth(e.InDate, now) })
	openEntry := findOpenEntry(entries, now)

	return Metrics{
		TodayHours:    todayHours,
		MonthHours:    monthHours,
		TodayEarnings: todayHours * cfg.HourlyRate,
		MonthEarnings: monthHours * cfg.HourlyRate,
		Config:        cfg,
		OpenEntry:     openEntry,
	}
}

func sumHours(entries []Entry, now time.Time, predicate func(Entry) bool) float64 {
	total := 0.0
	for _, e := range entries {
		if predicate(e) {
			total += entryHours(e, now)
		}
	}
	return total
}

func entryHours(e Entry, now time.Time) float64 {
	end := now
	if e.OutDate != nil {
		end = *e.OutDate
	}
	if h := end.Sub(e.InDate).Hours(); h > 0 {
		return h
	}
	return 0
}

func findOpenEntry(entries []Entry, now time.Time) *Entry {
	for i := range entries {
		if entries[i].IsOpen() && isSameDay(entries[i].InDate, now) {
			return &entries[i]
		}
	}
	return nil
}

func isSameDay(a, b time.Time) bool {
	return a.Year() == b.Year() && a.Month() == b.Month() && a.Day() == b.Day()
}

func isSameMonth(a, b time.Time) bool {
	return a.Year() == b.Year() && a.Month() == b.Month()
}

func formatDuration(hours float64) string {
	h := int(hours)
	m := int((hours - float64(h)) * 60)
	return fmt.Sprintf("%dh%02dm", h, m)
}

func formatCurrency(symbol string, amount float64) string {
	return fmt.Sprintf("%s %.2f", symbol, amount)
}

type waybarOutput struct {
	Text    string `json:"text"`
	Tooltip string `json:"tooltip"`
	Class   string `json:"class"`
}

func buildOutput(m Metrics, now time.Time) waybarOutput {
	return waybarOutput{
		Text:    buildText(m),
		Tooltip: buildTooltip(m, now),
		Class:   buildClass(m),
	}
}

func buildText(m Metrics) string {
	if m.Config.HasRate() {
		return fmt.Sprintf("%s", formatCurrency(m.Config.Currency, m.TodayEarnings))
	}
	return fmt.Sprintf("%s", formatDuration(m.TodayHours))
}

func buildTooltip(m Metrics, now time.Time) string {
	todayLine := fmt.Sprintf("📅 Hoje:  %s", formatDuration(m.TodayHours))
	monthLine := fmt.Sprintf("📆 Mês:   %s", formatDuration(m.MonthHours))

	if m.Config.HasRate() {
		todayLine += fmt.Sprintf("  •  %s", formatCurrency(m.Config.Currency, m.TodayEarnings))
		monthLine += fmt.Sprintf("  •  %s", formatCurrency(m.Config.Currency, m.MonthEarnings))
	}

	return strings.Join([]string{
		todayLine,
		monthLine,
		"",
		buildOpenEntryLine(m),
		"",
		fmt.Sprintf("🔄 %s", now.Format("15:04:05")),
	}, "\n")
}

func buildOpenEntryLine(m Metrics) string {
	if m.OpenEntry == nil {
		return "⚪ Sem registro aberto"
	}
	return fmt.Sprintf("🟢 Em aberto desde %s", m.OpenEntry.InDate.Format("15:04"))
}

func buildClass(m Metrics) string {
	if m.OpenEntry != nil {
		return "open"
	}
	return "closed"
}

func run() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot resolve home directory: %w", err)
	}

	base := filepath.Join(home, ".hourly")
	now := time.Now()
	cfg := loadConfig(filepath.Join(base, "config.json"))
	entries := loadEntries(filepath.Join(base, "data.json"))
	metrics := computeMetrics(entries, cfg, now)
	output := buildOutput(metrics, now)

	return json.NewEncoder(os.Stdout).Encode(output)
}

func main() {
	if err := run(); err != nil {
		_ = json.NewEncoder(os.Stdout).Encode(map[string]string{
			"text":    "erro",
			"tooltip": err.Error(),
			"class":   "error",
		})
		os.Exit(1)
	}
}
