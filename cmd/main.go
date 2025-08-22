package main

import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"time"
)

func main() {
	fmt.Println("Cross-Platform Application")
	fmt.Println("========================")
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Architecture: %s\n", runtime.GOARCH)
	fmt.Printf("Go Version: %s\n", runtime.Version())
	fmt.Printf("Current Time: %s\n", time.Now().Format("2006-01-02 15:04:05"))
	
	if len(os.Args) > 1 {
		fmt.Printf("Arguments: %v\n", os.Args[1:])
	}
	
	fmt.Println("\nApplication running successfully!")
	fmt.Println("\nPress Enter to exit...")
	
	// Wait for user input before exiting
	reader := bufio.NewReader(os.Stdin)
	reader.ReadLine()
}