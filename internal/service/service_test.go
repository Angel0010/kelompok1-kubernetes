package service_test

import (
	"testing"

	"github.com/taskflow/api/internal/model"
	"github.com/taskflow/api/internal/repository"
	"github.com/taskflow/api/internal/service"
)

func newSvc() *service.TaskService {
	return service.NewTaskService(repository.NewMemoryRepository())
}

// =====================
// CalculateCompletionRate
// =====================
func TestCalculateCompletionRate(t *testing.T) {
	//t.Skip("skip untuk simulasi bug lolos pipeline (rollback scenario)") //tambahkan saat ingin mencek skenario 5
	tests := []struct {
		name  string
		tasks []model.Task
		want  float64
	}{
		{"tidak ada task", []model.Task{}, 0},
		{"semua done", []model.Task{{Status: model.StatusDone}, {Status: model.StatusDone}}, 100},
		{
			"sepertiga selesai",
			[]model.Task{
				{Status: model.StatusDone},
				{Status: model.StatusTodo},
				{Status: model.StatusTodo},
			},
			33.33,
		},
		{"setengah selesai", []model.Task{{Status: model.StatusDone}, {Status: model.StatusTodo}}, 50},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := service.CalculateCompletionRate(tc.tasks)
			diff := got - tc.want
			if diff < 0 {
				diff = -diff
			}
			if diff > 0.01 {
				t.Errorf("got %.2f want %.2f", got, tc.want)
			}
		})
	}
}

// =====================
// CREATE
// =====================
func TestCreate(t *testing.T) {
	svc := newSvc()

	t.Run("success default priority", func(t *testing.T) {
		task, err := svc.Create(model.CreateTaskRequest{Title: "Test"})
		if err != nil {
			t.Fatal(err)
		}
		if task.Priority != model.PriorityMedium {
			t.Error("expected default medium")
		}
	})

	t.Run("empty title", func(t *testing.T) {
		_, err := svc.Create(model.CreateTaskRequest{Title: ""})
		if err == nil {
			t.Error("expected error")
		}
	})

	t.Run("invalid priority", func(t *testing.T) {
		_, err := svc.Create(model.CreateTaskRequest{
			Title:    "T",
			Priority: "invalid",
		})
		if err == nil {
			t.Error("expected error")
		}
	})
}

// =====================
// GET
// =====================
func TestGetByID(t *testing.T) {
	svc := newSvc()

	t.Run("not found", func(t *testing.T) {
		_, err := svc.GetByID("x")
		if err == nil {
			t.Error("expected error")
		}
	})

	t.Run("found", func(t *testing.T) {
		task, _ := svc.Create(model.CreateTaskRequest{Title: "A"})
		got, err := svc.GetByID(task.ID)
		if err != nil {
			t.Fatal(err)
		}
		if got.ID != task.ID {
			t.Error("ID mismatch")
		}
	})
}

// =====================
// GET ALL
// =====================
func TestGetAll(t *testing.T) {
	svc := newSvc()

	svc.Create(model.CreateTaskRequest{Title: "A"})
	task2, _ := svc.Create(model.CreateTaskRequest{Title: "B"})

	done := model.StatusDone
	svc.Update(task2.ID, model.UpdateTaskRequest{Status: &done})

	t.Run("all", func(t *testing.T) {
		tasks, _ := svc.GetAll("")
		if len(tasks) != 2 {
			t.Error("expected 2 tasks")
		}
	})

	t.Run("filter done", func(t *testing.T) {
		tasks, _ := svc.GetAll("done")
		if len(tasks) != 1 {
			t.Error("expected 1 done task")
		}
	})

	t.Run("invalid filter", func(t *testing.T) {
		_, err := svc.GetAll("invalid")
		if err == nil {
			t.Error("expected error")
		}
	})
}

// =====================
// UPDATE
// =====================
func TestUpdate(t *testing.T) {
	svc := newSvc()
	task, _ := svc.Create(model.CreateTaskRequest{Title: "Old"})

	t.Run("update title", func(t *testing.T) {
		newTitle := "New"
		updated, err := svc.Update(task.ID, model.UpdateTaskRequest{
			Title: &newTitle,
		})
		if err != nil {
			t.Fatal(err)
		}
		if updated.Title != "New" {
			t.Error("title not updated")
		}
	})

	t.Run("update status done", func(t *testing.T) {
		done := model.StatusDone
		updated, _ := svc.Update(task.ID, model.UpdateTaskRequest{
			Status: &done,
		})
		if updated.CompletedAt == nil {
			t.Error("completed_at should be set")
		}
	})

	t.Run("invalid status", func(t *testing.T) {
		s := model.Status("invalid")
		_, err := svc.Update(task.ID, model.UpdateTaskRequest{
			Status: &s,
		})
		if err == nil {
			t.Error("expected error")
		}
	})

	t.Run("not found", func(t *testing.T) {
		_, err := svc.Update("x", model.UpdateTaskRequest{})
		if err == nil {
			t.Error("expected error")
		}
	})
}

// =====================
// DELETE
// =====================
func TestDelete(t *testing.T) {
	svc := newSvc()

	t.Run("success", func(t *testing.T) {
		task, _ := svc.Create(model.CreateTaskRequest{Title: "A"})
		_, err := svc.Delete(task.ID)
		if err != nil {
			t.Fatal(err)
		}
	})

	t.Run("not found", func(t *testing.T) {
		_, err := svc.Delete("x")
		if err == nil {
			t.Error("expected error")
		}
	})
}

// =====================
// STATS
// =====================
func TestGetStats(t *testing.T) {
	svc := newSvc()

	svc.Create(model.CreateTaskRequest{Title: "A"})
	task2, _ := svc.Create(model.CreateTaskRequest{Title: "B"})

	done := model.StatusDone
	svc.Update(task2.ID, model.UpdateTaskRequest{Status: &done})

	stats, err := svc.GetStats()
	if err != nil {
		t.Fatal(err)
	}

	if stats.Total != 2 {
		t.Error("wrong total")
	}
	if stats.ByStatus["done"] != 1 {
		t.Error("wrong done count")
	}
}